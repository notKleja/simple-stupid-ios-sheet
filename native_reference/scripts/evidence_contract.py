"""Native acceptance controls; legacy adaptation never rewrites hashed sources."""
import copy
import gzip
import json
import math

LEGACY_ADAPTER = "native-legacy-v1"
REST_KEYS = ("sheet.x", "sheet.y", "sheet.width", "sheet.height", "sheet.left_inset", "sheet.right_inset", "sheet.bottom_inset")
BOUNDARIES = ("present.requested", "present.completed", "detent.requested", "detent.requested", "dismiss.requested", "dismiss.completed")
CONFIGURATION_KEYS = ("trial", "detents", "surface", "grabber", "page_sizing", "modal_in_presentation", "largest_undimmed", "presentation_style", "preferred_content_size", "placement", "edge_attached_in_compact_height", "width_follows_preferred_content_size", "scroll_expansion")

def require(condition, reason):
    if not condition:
        raise ValueError(reason)

def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)

def canonical_id(value):
    return {"com.apple.UIKit.medium": "medium", "com.apple.UIKit.large": "large"}.get(value, value)

def read(path):
    with (gzip.open if str(path).endswith(".gz") else open)(path, "rt") as stream:
        return [json.loads(line) for line in stream if line.strip()]

def adapt_legacy(rows, adapter=None):
    require(bool(rows), "empty trace")
    version = rows[0].get("native_contract_version", 1)
    if version == 2:
        return rows
    require(version == 1 and adapter == LEGACY_ADAPTER, "legacy trace requires explicit native-legacy-v1 adapter")
    result = copy.deepcopy(rows)
    for row in result:
        row["compatibility_adapter"] = LEGACY_ADAPTER
        if row.get("type") == "frame":
            reasons = row.setdefault("unavailable", {})
            for section in ("metrics", "state"):
                for key, value in row.get(section, {}).items():
                    if value is None:
                        reasons.setdefault(key, f"{LEGACY_ADAPTER}: original null; legacy instrumentation did not expose this field")
            state = row.get("state", {})
            for key in ("selected_detent", "target_detent"):
                if key in state:
                    raw = state[key]
                    state[key] = canonical_id(raw)
                    if raw != state[key]:
                        row.setdefault("raw_uikit_identifier", {})[key] = raw
        elif row.get("name") == "detent.changed":
            raw = row["data"].get("selected")
            row["data"]["selected"] = canonical_id(raw)
            row["raw_uikit_identifier"] = raw
    return result

def validate_run(rows, adapter=None):
    rows = adapt_legacy(rows, adapter)
    header = rows[0]
    require(header.get("type") == "session", "session must be first")
    require(header.get("implementation") == "native" and header.get("evidence_kind") == "runtime", "native runtime evidence required")
    require(isinstance(header.get("run_id"), str) and header["run_id"], "run ID required")
    require(header["os"].get("build") and header["os"].get("version"), "observed OS/build required")
    require(header["device"].get("runtime_kind") in ("simulator", "virtual_device", "physical_device"), "explicit runtime kind required")
    if header.get("native_contract_version") == 2:
        require(all(key in header["configuration"] for key in CONFIGURATION_KEYS), "complete v2 effective configuration required")
        require(header["configuration"]["presentation_style"] in ("page_sheet", "form_sheet"), "unknown presentation style")
        require(header["configuration"]["placement"] in ("automatic", "center", "leading", "trailing"), "unknown placement")
    hz = header["device"]["refresh_hz"]
    require(finite(hz) and hz > 0, "declared refresh capability required")
    previous_seq = previous_time = previous_frame = -1
    frames, events = [], []
    for index, row in enumerate(rows):
        require(row.get("schema_version") == 1 and row.get("run_id") == header["run_id"], "envelope/run ID mismatch")
        require(type(row.get("seq")) is int and row["seq"] > previous_seq, "sequence must strictly increase")
        require(type(row.get("t_ns")) is int and row["t_ns"] >= max(0, previous_time), "monotonic integer timestamp required")
        previous_seq, previous_time = row["seq"], row["t_ns"]
        require(row.get("type") in ("session", "event", "frame"), "unknown record type")
        require(row["type"] != "session" or index == 0, "duplicate session")
        if row["type"] == "event":
            require(row.get("name") != "run.error", "run explicitly invalidated by recorder")
            require(isinstance(row.get("name"), str) and isinstance(row.get("data"), dict), "invalid event")
            events.append(row)
        elif row["type"] == "frame":
            require(row["t_ns"] > previous_frame, "frame timestamps must strictly increase")
            previous_frame = row["t_ns"]
            require(isinstance(row.get("metrics"), dict) and isinstance(row.get("state"), dict), "frame fields required")
            require(all(value is None or finite(value) for value in row["metrics"].values()), "invalid numeric metric")
            for section in ("metrics", "state"):
                for key, value in row[section].items():
                    if value is None:
                        reason = row.get("unavailable", {}).get(key)
                        require(isinstance(reason, str) and bool(reason.strip()), f"null {section}.{key} lacks unavailable reason")
            for key in ("selected_detent", "target_detent"):
                value = row["state"].get(key)
                require(value == canonical_id(value), f"noncanonical {key}")
            frames.append(row)
    core = [event for event in events if event["name"] in BOUNDARIES]
    require(tuple(event["name"] for event in core) == BOUNDARIES, "expected complete ordered programmatic boundary sequence")
    require([event["data"].get("target") for event in core if event["name"] == "detent.requested"] == ["large", "medium"], "expected large then medium requests")
    require(all(core[i]["t_ns"] < core[i+1]["t_ns"] for i in range(len(core)-1)), "boundary times must strictly increase")
    period = 1_000_000_000 / hz
    windows = {}
    for phase, boundary in zip(("medium_initial", "large", "medium_return"), core[2:5]):
        end = boundary["t_ns"]
        start = end - 400_000_000
        observed = [frame for frame in frames if start <= frame["t_ns"] < end]
        require(len(observed) >= 2, f"{phase}: resting window missing")
        require(observed[0]["t_ns"] - start <= 2 * period and end - observed[-1]["t_ns"] <= 2 * period, f"{phase}: resting window endpoints incomplete")
        require(all(observed[i]["t_ns"] - observed[i-1]["t_ns"] <= 2 * period for i in range(1,len(observed))), f"{phase}: resting window sampling gap")
        for key in REST_KEYS:
            values = [frame["metrics"].get(key) for frame in observed]
            require(all(finite(value) for value in values), f"{phase}: required resting {key} unavailable")
            require(max(values) - min(values) <= .25, f"{phase}: resting {key} not stable at .25pt precision")
        windows[phase] = observed
    return rows, windows

def identity(header):
    configuration = {key: value for key, value in header["configuration"].items() if key != "trial"}
    return {key: header[key] for key in ("scenario_id", "os", "device", "environment")} | {"configuration": configuration}

def validate_cohort(runs, adapter=None):
    require(len(runs) == 10, "exactly ten artifacts required per profile")
    validated = [validate_run(rows, adapter) for rows in runs]
    headers = [rows[0] for rows, _ in validated]
    require(len({header["run_id"] for header in headers}) == 10, "ten unique run IDs required")
    trials = [header["configuration"].get("trial") for header in headers]
    require(all(type(trial) is int for trial in trials) and set(trials) == set(range(1,11)), "ten unique trial IDs 1..10 required")
    require(all(identity(header) == identity(headers[0]) for header in headers), "mixed OS/device/configuration/environment cohort")
    return validated
