#!/usr/bin/env python3
"""Compare observed JSONL trace pairs. Standard library only; never invent samples."""
import argparse
from bisect import bisect_left
import hashlib
import gzip
import json
import math
from pathlib import Path
import statistics
import sys
from functools import lru_cache

APPROVED_AUXILIARY_EVENTS = frozenset({"detent.resolved", "batch.completed"})


class TraceError(ValueError):
    pass


def finite(value):
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        return False
    try:
        return math.isfinite(value)
    except OverflowError:
        return False


def require(condition, message):
    if not condition:
        raise TraceError(message)


@lru_cache(maxsize=1)
def trace_schema():
    return json.loads((Path(__file__).resolve().parents[1] / "measurement/schema/trace.schema.json").read_text())


def schema_equal(value, expected):
    # JSON booleans are distinct from numbers even though Python True == 1.
    return value == expected and (not isinstance(value, bool) and not isinstance(expected, bool)
                                 or type(value) is type(expected))


def validate_schema(value, schema, path="$", root=None):
    """Validate the declarative subset used by our fixed v1 schema, not arbitrary schemas."""
    root = schema if root is None else root
    if "$ref" in schema:
        reference = schema["$ref"]
        require(reference.startswith("#/"), "only local trace schema references supported")
        target = root
        for key in reference[2:].split("/"):
            target = target[key]
        return validate_schema(value, target, path, root)
    if "const" in schema:
        require(schema_equal(value, schema["const"]), f"{path}: invalid constant")
    if "enum" in schema:
        require(any(schema_equal(value, choice) for choice in schema["enum"]), f"{path}: invalid enum value")
    if "type" in schema:
        kinds = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
        matches = {"object": isinstance(value, dict), "array": isinstance(value, list),
                   "string": isinstance(value, str), "number": finite(value),
                   "integer": isinstance(value, int) and not isinstance(value, bool),
                   "boolean": isinstance(value, bool), "null": value is None}
        require(any(matches.get(kind, False) for kind in kinds), f"{path}: expected {kinds}")
    if isinstance(value, dict):
        for key in schema.get("required", []):
            require(key in value, f"{path}.{key}: required field missing")
        properties = schema.get("properties", {})
        for key, item in value.items():
            if key in properties:
                validate_schema(item, properties[key], path + "." + key, root)
            elif isinstance(schema.get("additionalProperties"), dict):
                validate_schema(item, schema["additionalProperties"], path + "." + key, root)
            elif schema.get("additionalProperties") is False:
                raise TraceError(f"{path}.{key}: additional field not allowed")
    if isinstance(value, str) and "minLength" in schema:
        require(len(value) >= schema["minLength"], f"{path}: string too short")
    if finite(value):
        if "minimum" in schema:
            require(value >= schema["minimum"], f"{path}: below minimum")
        if "exclusiveMinimum" in schema:
            require(value > schema["exclusiveMinimum"], f"{path}: must exceed minimum")
    for child in schema.get("allOf", []):
        validate_schema(value, child, path, root)
    if "if" in schema:
        try:
            validate_schema(value, schema["if"], path, root)
        except TraceError:
            branch = schema.get("else")
        else:
            branch = schema.get("then")
        if branch is not None:
            validate_schema(value, branch, path, root)


def validate(records, role):
    require(isinstance(records, list) and records, f"{role}: empty trace")
    header = records[0]
    require(isinstance(header, dict), f"{role}: malformed session")
    validate_schema(header, trace_schema(), role + ".session")
    require(header.get("type") == "session", f"{role}: session must be first")
    required = ("scenario_id", "implementation", "evidence_kind", "os", "device", "environment", "configuration")
    require(all(key in header for key in required), f"{role}: incomplete session metadata")
    require(header["implementation"] == role, f"{role}: wrong implementation")
    require(header["evidence_kind"] in ("runtime", "synthetic"), f"{role}: unknown evidence kind")
    require(all(key in header["os"] for key in ("version", "build")), f"{role}: incomplete os metadata")
    require(all(key in header["device"] for key in ("model", "logical_size", "physical_size", "scale", "refresh_hz")), f"{role}: incomplete device metadata")
    require(all(key in header["environment"] for key in ("orientation", "safe_area", "size_classes", "status_bar", "keyboard")), f"{role}: incomplete environment metadata")
    if header["evidence_kind"] == "runtime":
        require(isinstance(header["os"]["build"], str) and bool(header["os"]["build"]), f"{role}: unknown runtime os build")
    previous_seq, previous_time = -1, -1
    previous_frame = -1
    frames, events = [], []
    for index, record in enumerate(records):
        require(isinstance(record, dict), f"{role}: record {index} is not an object")
        validate_schema(record, trace_schema(), f"{role}.record[{index}]")
        require(record.get("schema_version") == 1, f"{role}: unsupported schema")
        require(record.get("run_id") == header.get("run_id") and bool(header.get("run_id")), f"{role}: inconsistent run_id")
        seq, timestamp = record.get("seq"), record.get("t_ns")
        require(isinstance(seq, int) and not isinstance(seq, bool) and seq > previous_seq, f"{role}: seq must strictly increase")
        require(isinstance(timestamp, int) and not isinstance(timestamp, bool) and timestamp >= previous_time and timestamp >= 0, f"{role}: monotonic integer t_ns required")
        previous_seq, previous_time = seq, timestamp
        kind = record.get("type")
        require(kind in ("session", "frame", "event"), f"{role}: unknown record type")
        if kind == "session":
            require(index == 0, f"{role}: duplicate session")
        elif kind == "frame":
            require(timestamp > previous_frame, f"{role}: duplicate frame timestamp")
            previous_frame = timestamp
            require(isinstance(record.get("metrics"), dict) and isinstance(record.get("state"), dict), f"{role}: malformed frame")
            require(all(value is None or finite(value) for value in record["metrics"].values()), f"{role}: nonfinite/non-numeric metric")
            frames.append(record)
        else:
            require(isinstance(record.get("name"), str) and record["name"] and isinstance(record.get("data"), dict), f"{role}: malformed event")
            events.append(record)
    require(len(frames) >= 2, f"{role}: at least two observed frames required")
    return header, frames, events


def indexed_events(events):
    counts, result = {}, {}
    for event in events:
        name = event["name"]
        ordinal = counts.get(name, 0)
        counts[name] = ordinal + 1
        result[f"{name}#{ordinal}"] = event
    return result


def interpolate(times, values, timestamp):
    require(times[0] <= timestamp <= times[-1], "candidate coverage: extrapolation forbidden")
    index = bisect_left(times, timestamp)
    if times[index] == timestamp:
        return values[index]
    left, right = times[index - 1], times[index]
    ratio = (timestamp - left) / (right - left)
    return values[index - 1] + ratio * (values[index] - values[index - 1])


def rms(values):
    return math.sqrt(sum(value * value for value in values) / len(values))


def velocity(times, values):
    return [(values[i] - values[i - 1]) * 1_000_000_000 / (times[i] - times[i - 1]) for i in range(1, len(times))]


def settle_time(times, values, target, epsilon):
    """First sample of final continuously in-band suffix; no unseen dwell inferred."""
    if abs(values[-1] - target) > epsilon:
        return None
    index = len(values) - 1
    while index > 0 and abs(values[index - 1] - target) <= epsilon:
        index -= 1
    return times[index] / 1_000_000


def metric_report(times, reference, candidate, limits):
    differences = [b - a for a, b in zip(reference, candidate)]
    velocity_errors = [b - a for a, b in zip(velocity(times, reference), velocity(times, candidate))]
    result = {"samples": len(times), "absolute_mean": statistics.fmean(abs(x) for x in differences),
              "signed_mean": statistics.fmean(differences), "rms": rms(differences),
              "max": max(abs(x) for x in differences), "final": abs(differences[-1]),
              "velocity_rms": rms(velocity_errors), "velocity_max": max(abs(x) for x in velocity_errors),
              "limits": limits, "unit": "recorder_metric_units", "excluded_samples": 0}
    epsilon = limits.get("final", .25)
    native_settle = settle_time(times, reference, reference[-1], epsilon)
    candidate_settle = settle_time(times, candidate, reference[-1], epsilon)
    result["settling"] = {"native_ms": native_settle, "candidate_ms": candidate_settle,
                          "error_ms": None if candidate_settle is None else abs(candidate_settle - native_settle),
                          "threshold": epsilon,
                          "native_observed_dwell_ms": (times[-1] / 1_000_000 - native_settle)}
    direction = 1 if reference[-1] >= reference[0] else -1
    result["overshoot"] = {"native": max(0, max(direction * (x - reference[-1]) for x in reference)),
                           "candidate": max(0, max(direction * (x - reference[-1]) for x in candidate))}
    result["pass"] = all(result[key] <= limit for key, limit in limits.items() if key != "settling_ms")
    if "settling_ms" in limits:
        result["pass"] &= result["settling"]["error_ms"] is not None and result["settling"]["error_ms"] <= limits["settling_ms"]
    return result


def repeat_noise(data):
    native, candidate = data.get("native_trials", []), data.get("candidate_trials", [])
    for name, values in (("native", native), ("candidate", candidate)):
        ids = data.get(name + "_run_ids", [])
        require(len(values) >= 10 and all(finite(x) for x in values), "noise: at least 10 finite independent trial statistics required")
        require(len(ids) == len(values) and len(set(ids)) == len(ids), "noise: distinct run IDs required per trial")
    # Each value is the same predeclared trial statistic, not adjacent frames.
    var_native, var_candidate = statistics.variance(native), statistics.variance(candidate)
    # Welch-Satterthwaite degrees of freedom; conservative two-sided t criticals.
    a, b = var_native / len(native), var_candidate / len(candidate)
    variance_mean = a + b
    df = math.inf if variance_mean == 0 else variance_mean ** 2 / (a * a / (len(native) - 1) + b * b / (len(candidate) - 1))
    critical = 1.96 if math.isinf(df) else next(value for threshold, value in ((10, 2.571), (20, 2.262), (30, 2.086), (60, 2.042), (120, 2.000), (math.inf, 1.980)) if df < threshold)
    return {"native_trials": len(native), "candidate_trials": len(candidate),
            "native_stddev": math.sqrt(var_native), "candidate_stddev": math.sqrt(var_candidate),
            "mean_difference_ci95": critical * math.sqrt(variance_mean),
            "welch_df": None if math.isinf(df) else df, "critical": critical,
            "policy": "report uncertainty; never expand targets automatically"}


def compare(request):
    report = {"schema_version": 1, "verdict": "FAIL", "issues": [], "metrics": {}, "states": {},
              "event_timing": {}, "noise": {}, "native_parity_eligible": False,
              "proof_scope": "unvalidated_trace_pair"}
    try:
        require(isinstance(request, dict), "request must be an object")
        nh, nf, ne = validate(request.get("native"), "native")
        ch, cf, ce = validate(request.get("candidate"), "flutter")
        cfg = request.get("config", {})
        require(isinstance(cfg, dict) and cfg.get("metrics"), "explicit nonempty metric acceptance configuration required")
        baseline = json.loads((Path(__file__).resolve().parents[1] / "measurement/profiles/full.json").read_text())
        policy = cfg.get("exact_event_data")
        if policy is not None:
            require(isinstance(policy, dict) and all(isinstance(name, str) and isinstance(fields, list)
                    and all(isinstance(field, str) and field for field in fields) and len(set(fields)) == len(fields)
                    for name, fields in policy.items()), "exact_event_data must map event names to unique semantic field lists")
        missing = []
        for name, required_limits in baseline["metrics"].items():
            given = cfg["metrics"].get(name, {})
            if not all(key in given and finite(given[key]) and given[key] <= limit for key, limit in required_limits.items()):
                missing.append(name)
        missing += ["state." + name for name in baseline["states"] if name not in cfg.get("states", [])]
        if policy is not None:
            missing += [f"event_data.{name}.{field}" for name, fields in baseline["exact_event_data"].items()
                        for field in fields if field not in policy.get(name, [])]
        if cfg.get("event_tolerance_frames", 1) > baseline["event_tolerance_frames"]:
            missing.append("event_timing_target")
        if cfg.get("max_gap_frames", 2) > baseline["max_gap_frames"]:
            missing.append("sampling_gap_target")
        report["full_acceptance_missing"] = missing
        report["acceptance_scope"] = "diagnostic_subset" if missing else "full_metric_profile"
        for key in ("scenario_id", "os", "device", "environment", "configuration"):
            if nh[key] != ch[key]:
                report["issues"].append(f"incompatible {key}; cross-device/build/configuration comparison forbidden")
        report["proof_scope"] = "synthetic_math_only" if "synthetic" in (nh["evidence_kind"], ch["evidence_kind"]) else "runtime_trace_pair_only"
        report["native_parity_eligible"] = report["proof_scope"] == "runtime_trace_pair_only" and not report["issues"] and not missing
        report["runs"] = {"native": nh["run_id"], "candidate": ch["run_id"], "scenario_id": nh["scenario_id"]}
        alignment = cfg.get("alignment", {})
        require(not any(e["name"] == "environment.changed" for e in ne + ce), "environment changed: split analysis at event boundary")
        auxiliary = cfg.get("auxiliary_events", [])
        require(isinstance(auxiliary, list) and all(isinstance(name, str) for name in auxiliary), "invalid auxiliary event policy")
        require(set(auxiliary) <= APPROVED_AUXILIARY_EVENTS, "auxiliary exclusions limited to approved probe markers: detent.resolved, batch.completed")
        require(alignment.get("event") not in auxiliary, "alignment event cannot be auxiliary")
        report["auxiliary_event_counts"] = {}
        for role, events in (("native", ne), ("candidate", ce)):
            report["auxiliary_event_counts"][role] = {name: sum(e["name"] == name for e in events) for name in auxiliary}
        ne = [e for e in ne if e["name"] not in auxiliary]
        ce = [e for e in ce if e["name"] not in auxiliary]
        boundary = f"{alignment.get('event')}#{alignment.get('occurrence', 0)}"
        nev, cev = indexed_events(ne), indexed_events(ce)
        require(boundary in nev and boundary in cev, f"missing real alignment boundary {boundary}")
        nt, ct = nev[boundary]["t_ns"], cev[boundary]["t_ns"]
        report["alignment"] = {"boundary": boundary, "native_t_ns": nt, "candidate_t_ns": ct,
                               "clock_offset_ns": ct - nt, "method": "observed_event_boundary"}
        hz = nh["device"]["refresh_hz"]
        require(finite(hz) and hz > 0, "native observable refresh_hz required for frame tolerances")
        frame_ms = 1000 / hz
        report["native_frame_ms"] = frame_ms
        for key in sorted(set(nev) | set(cev)):
            if key not in nev or key not in cev:
                report["issues"].append(f"event sequence mismatch: {key}")
                continue
            n, c = nev[key], cev[key]
            error = abs((c["t_ns"] - ct) - (n["t_ns"] - nt)) / 1_000_000
            passed = error <= frame_ms * cfg.get("event_tolerance_frames", 1)
            report["event_timing"][key] = {"error_ms": error, "limit_ms": frame_ms * cfg.get("event_tolerance_frames", 1), "pass": passed}
            if not passed:
                report["issues"].append(f"event timing exceeds one configured native-frame limit: {key}")
            mandatory_fields = baseline["exact_event_data"].get(n["name"], [])
            if policy is None:
                data_match = n["data"] == c["data"] and all(field in n["data"] and n["data"][field] is not None for field in mandatory_fields)
            else:
                fields = set(mandatory_fields) | set(policy.get(n["name"], []))
                data_match = all(field in n["data"] and field in c["data"] and n["data"][field] is not None
                                 and n["data"][field] == c["data"][field] for field in fields)
            if not data_match:
                report["issues"].append(f"event data/outcome mismatch: {key}")
        # Comparing exact event order also catches swapped same-time handoffs.
        if [e["name"] for e in ne] != [e["name"] for e in ce]:
            report["issues"].append("event order mismatch")
        native_total, candidate_total = len(nf), len(cf)
        start, end = nt, math.inf
        window = cfg.get("window")
        if window is not None:
            require(isinstance(window, dict), "window must specify observed start/end events")
            start_key = f"{window.get('start_event')}#{window.get('start_occurrence', 0)}"
            end_key = f"{window.get('end_event')}#{window.get('end_occurrence', 0)}"
            require(start_key in nev and start_key in cev and end_key in nev and end_key in cev, "missing observed phase window boundary")
            start, end = nev[start_key]["t_ns"], nev[end_key]["t_ns"]
            require(start < end and cev[start_key]["t_ns"] < cev[end_key]["t_ns"], "invalid phase boundary order")
            report["window"] = {"start_boundary": start_key, "end_boundary": end_key, "end_inclusive": False,
                                "native_start_ns": start, "native_end_ns": end,
                                "candidate_start_ns": cev[start_key]["t_ns"], "candidate_end_ns": cev[end_key]["t_ns"]}
        else:
            report["window"] = {"start_boundary": boundary, "end_boundary": "trace_end", "end_inclusive": True}
        nf = [f for f in nf if start <= f["t_ns"] < end]
        require(len(nf) >= 2, "insufficient native frames in selected phase")
        ntime = [f["t_ns"] - nt for f in nf]
        all_ctime = [f["t_ns"] - ct for f in cf]
        require(all_ctime[0] <= ntime[0] and all_ctime[-1] >= ntime[-1], "candidate coverage incomplete; reference tail cannot be trimmed")
        first = bisect_left(all_ctime, ntime[0])
        if all_ctime[first] != ntime[0]:
            first -= 1
        last = bisect_left(all_ctime, ntime[-1])
        cf = cf[first:last + 1]
        ctime = all_ctime[first:last + 1]
        require(len(cf) >= 2, "insufficient candidate interpolation brackets")
        report["window"]["native_frames_outside"] = native_total - len(nf)
        report["window"]["candidate_frames_outside"] = candidate_total - len(cf)
        report["window"]["candidate_interpolation_brackets_observed"] = True
        require(ctime[0] <= ntime[0] and ctime[-1] >= ntime[-1], "candidate coverage incomplete; reference tail cannot be trimmed")
        gap_limit = frame_ms * cfg.get("max_gap_frames", 2) * 1_000_000
        require(finite(gap_limit) and gap_limit > 0, "positive max_gap_frames required")
        for role, times in (("native", ntime), ("candidate", ctime)):
            gaps = [times[i] - times[i - 1] for i in range(1, len(times))]
            if max(gaps) > gap_limit + 1:
                report["issues"].append(f"{role}: sampling gap exceeds {cfg.get('max_gap_frames', 2)} native frames")
        report["coverage"] = {"native_start_ms": ntime[0] / 1_000_000, "native_end_ms": ntime[-1] / 1_000_000,
                              "candidate_start_ms": ctime[0] / 1_000_000, "candidate_end_ms": ctime[-1] / 1_000_000}
        union_time = sorted(set(ntime) | {t for t in ctime if ntime[0] <= t <= ntime[-1]})
        report["comparison_grid"] = "union_of_observed_timestamps"
        report["comparison_samples"] = len(union_time)
        for name, limits in cfg["metrics"].items():
            require(isinstance(limits, dict) and limits, f"{name}: nonempty limits required")
            require(all(key in ("rms", "max", "final", "velocity_rms", "velocity_max", "absolute_mean", "settling_ms") and finite(value) and value >= 0 for key, value in limits.items()), f"{name}: invalid acceptance limits")
            nvalues, cvalues = [f["metrics"].get(name) for f in nf], [f["metrics"].get(name) for f in cf]
            if not all(finite(x) for x in nvalues + cvalues):
                report["issues"].append(f"required metric missing/null: {name}")
                continue
            reference = [interpolate(ntime, nvalues, t) for t in union_time]
            aligned = [interpolate(ctime, cvalues, t) for t in union_time]
            result = metric_report(union_time, reference, aligned, limits)
            report["metrics"][name] = result
            if not result["pass"]:
                report["issues"].append(f"metric exceeds limits: {name}")
            if name in request.get("noise", {}):
                noise = repeat_noise(request["noise"][name])
                report["noise"][name] = noise
                target = min(limits.values())
                if noise["mean_difference_ci95"] > target:
                    report["issues"].append(f"measurement noise unresolved at target precision: {name}")
        for name in cfg.get("states", []):
            require(isinstance(name, str), "invalid required state name")
            nvalues = [f["state"].get(name) for f in nf]
            cvalues = [f["state"].get(name) for f in cf]
            observed = all(value is not None for value in nvalues + cvalues)
            # State transitions are held, never numerically interpolated.
            aligned = [cvalues[max(0, bisect_left(ctime, t) - (t not in ctime))] for t in ntime]
            def transitions(values):
                return [value for i, value in enumerate(values) if i == 0 or value != values[i - 1]]
            candidate_in_window = [aligned[0]] + [value for t, value in zip(ctime, cvalues) if ntime[0] < t <= ntime[-1]]
            matched = observed and nvalues == aligned and transitions(nvalues) == transitions(candidate_in_window)
            report["states"][name] = {"match": matched, "native_final": nvalues[-1], "candidate_final": aligned[-1], "observed": observed}
            if not matched:
                report["issues"].append(f"exact state/interaction mismatch or missing: {name}")
        report["verdict"] = "FAIL" if report["issues"] else "PASS"
        report["native_parity_eligible"] &= report["verdict"] == "PASS"
    except (TraceError, TypeError, KeyError, IndexError, ValueError) as error:
        report["issues"].append(str(error))
        report["native_parity_eligible"] = False
    return report


def read_jsonl(path):
    if str(path).endswith(".gz"):
        with gzip.open(path, "rt", encoding="utf-8") as stream:
            lines = stream.read().splitlines()
    else:
        lines = Path(path).read_text().splitlines()
    return [json.loads(line) for line in lines if line.strip()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("native", nargs="?")
    parser.add_argument("candidate", nargs="?")
    parser.add_argument("--config")
    parser.add_argument("--request-stdin", action="store_true", help="JSON request with native/candidate record arrays; useful for synthetic tests")
    args = parser.parse_args()
    try:
        if args.request_stdin:
            request = json.load(sys.stdin)
        else:
            if not args.native or not args.candidate or not args.config:
                parser.error("native.jsonl candidate.jsonl --config profile.json required")
            request = {"native": read_jsonl(args.native), "candidate": read_jsonl(args.candidate), "config": json.loads(Path(args.config).read_text())}
        result = compare(request)
        if not args.request_stdin:
            result["artifacts"] = {role: {"path": path, "sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest()} for role, path in (("native", args.native), ("candidate", args.candidate), ("config", args.config))}
    except (OSError, json.JSONDecodeError) as error:
        result = {"verdict": "FAIL", "native_parity_eligible": False, "issues": [str(error)]}
    print(json.dumps(result, allow_nan=False, indent=2))
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
