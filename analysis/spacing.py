#!/usr/bin/env python3
"""Check container-geometry hypotheses on repeated programmatic native traces."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import sys

from compare import TraceError, finite, read_jsonl, require, rms, validate


def errors(values):
    require(bool(values), "no observed samples")
    return {"samples": len(values), "rms": rms(values), "max": max(abs(x) for x in values),
            "signed_min": min(values), "signed_max": max(values), "excluded_samples": 0}


def analyze(traces):
    require(isinstance(traces, list) and traces, "at least one trace required")
    report = {"schema_version": 1, "parity_proven": False, "proof_scope": "native_container_relationship_only",
              "calibration_status": "unverified; container relationships are provisional until independent coherent-tree calibration", "runs": [],
              "formulas": {"side": "x=I*(L-H)/(L-M); H=visible_height/(visible_width/W)",
                           "bottom_equal_side": "b=x",
                           "bottom_quadratic": "b=x+((L-M)/W)*x*(1-x/I)"},
              "limitations": ["container fields share one sampling pipeline; tiny arithmetic residual is not optical calibration", "programmatic medium/large only; no extrapolation to interactive drag or other geometry", "all original samples remain in residuals; anomalies are flagged, never trimmed", "callback completion is not physical settling"],
              "anomalies": [], "unavailable_frames": []}
    side_errors, symmetry_errors = [], []
    bottom_errors = {"large": {"equal_side": [], "quadratic": []}, "medium": {"equal_side": [], "quadratic": []}}
    for rows in traces:
        header, frames, events = validate(rows, "native")
        if header["evidence_kind"] == "synthetic":
            report["proof_scope"] = "synthetic_math_only"
        requests = [event for event in events if event["name"] == "detent.requested"]
        require(len(requests) == 2 and [event["data"].get("target") for event in requests] == ["large", "medium"],
                "requires large then medium programmatic boundaries")
        end = next((event["t_ns"] for event in events if event["name"] == "dismiss.requested" and event["t_ns"] > requests[1]["t_ns"]), None)
        require(end is not None, "dismiss boundary required for phase coverage")
        width = header["device"]["logical_size"]["width"]
        medium_frames = [frame for frame in frames if frame["t_ns"] < requests[0]["t_ns"]][-2:]
        large_frames = [frame for frame in frames if requests[0]["t_ns"] < frame["t_ns"] < requests[1]["t_ns"]][-2:]
        require(len(medium_frames) == len(large_frames) == 2, "two observed resting frames required at each endpoint")
        needed = ["sheet.width", "sheet.height", "sheet.left_inset", "sheet.bottom_inset", "sheet.y", "sheet.right_inset"]
        for frame in medium_frames + large_frames:
            require(all(finite(frame["metrics"].get(key)) for key in needed), "missing resting geometry")
        for endpoint in (medium_frames, large_frames):
            require(max(frame["metrics"]["sheet.height"] for frame in endpoint) - min(frame["metrics"]["sheet.height"] for frame in endpoint) <= .25,
                    "observed endpoint not at mission resting precision; extend acquisition")
        inset = statistics.median(frame["metrics"]["sheet.left_inset"] for frame in medium_frames)
        medium = statistics.median(frame["metrics"]["sheet.height"] / (frame["metrics"]["sheet.width"] / width) for frame in medium_frames)
        large = statistics.median(frame["metrics"]["sheet.height"] / (frame["metrics"]["sheet.width"] / width) for frame in large_frames)
        require(inset > 0 and large > medium, "nonzero medium inset and distinct resolved heights required")
        run = {"run_id": header["run_id"], "os": header["os"], "device": header["device"],
               "parameters": {"W": width, "M": medium, "L": large, "I": inset},
               "extent_domain": [medium / large, 1], "boundary_ns": {"large": requests[0]["t_ns"], "medium": requests[1]["t_ns"], "end": end},
               "sampling": "native timestamps retained; endpoint medians use final two observed pre-command frames",
               "present_first_visible_observed": any(event["name"] == "present.first_visible" for event in events), "samples": 0}
        report["runs"].append(run)
        for frame in frames:
            if not requests[0]["t_ns"] <= frame["t_ns"] < end:
                continue
            metric = frame["metrics"]
            if not all(finite(metric.get(key)) for key in needed) or metric.get("sheet.width", 0) <= 0:
                report["unavailable_frames"].append({"run_id": header["run_id"], "seq": frame["seq"],
                                                     "t_ns": frame["t_ns"], "unavailable": frame.get("unavailable", {}),
                                                     "missing_metrics": [key for key in needed if not finite(metric.get(key))]})
                continue
            unscaled = metric["sheet.height"] / (metric["sheet.width"] / width)
            x = metric["sheet.left_inset"]
            side_prediction = inset * (large - unscaled) / (large - medium)
            quadratic = x + (large - medium) / width * x * (1 - x / inset)
            direction = "large" if frame["t_ns"] < requests[1]["t_ns"] else "medium"
            side_errors.append(x - side_prediction)
            symmetry_errors.append(metric["sheet.right_inset"] - x)
            bottom_errors[direction]["equal_side"].append(metric["sheet.bottom_inset"] - x)
            bottom_errors[direction]["quadratic"].append(metric["sheet.bottom_inset"] - quadratic)
            run["samples"] += 1
            # A >2pt discrepancy from BOTH models is reported, not automatically discarded.
            if min(abs(metric["sheet.bottom_inset"] - x), abs(metric["sheet.bottom_inset"] - quadratic)) > 2:
                boundary = requests[0 if direction == "large" else 1]["t_ns"]
                report["anomalies"].append({"run_id": header["run_id"], "seq": frame["seq"], "t_ns": frame["t_ns"],
                                            "direction": direction, "relative_ms": (frame["t_ns"] - boundary) / 1_000_000,
                                            "sheet_y": metric["sheet.y"], "sheet_height": metric["sheet.height"],
                                            "side_inset": x, "bottom_inset": metric["sheet.bottom_inset"],
                                            "status": "unresolved_sampler_or_native_behavior"})
    report["side"] = errors(side_errors)
    report["left_right_symmetry"] = errors(symmetry_errors)
    report["bottom"] = {direction: {model: errors(values) for model, values in models.items()} for direction, models in bottom_errors.items()}
    report["trial_count"] = len(traces)
    if report["unavailable_frames"]:
        report["status"] = "unresolved"
        report["issues"] = ["Required geometry unavailable within analyzed transition phases; partial observed residuals cannot establish trajectory acceptance"]
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*")
    parser.add_argument("--request-stdin", action="store_true")
    parser.add_argument("--output")
    args = parser.parse_args()
    try:
        traces = json.load(sys.stdin) if args.request_stdin else [read_jsonl(path) for path in args.paths]
        result = analyze(traces)
        if not args.request_stdin:
            result["artifacts"] = [{"path": path, "sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest()} for path in args.paths]
    except (TraceError, OSError, KeyError, TypeError, ValueError, IndexError) as error:
        result = {"status": "unresolved", "issues": [str(error)], "parity_proven": False}
    serialized = json.dumps(result, allow_nan=False, indent=2)
    if args.output:
        path = Path(args.output)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(serialized + "\n")
        print(json.dumps({"output": str(path), "trial_count": result.get("trial_count"), "anomalies": len(result.get("anomalies", [])), "parity_proven": False}))
    else:
        print(serialized)
    return 1 if result.get("status") == "unresolved" else 0


if __name__ == "__main__":
    sys.exit(main())
