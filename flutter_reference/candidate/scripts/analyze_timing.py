#!/usr/bin/env python3
"""Report unchanged comparator results plus honest, observed phase coverage."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "analysis"))
from compare import compare, read_jsonl, schema_equal  # noqa: E402


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(directory):
    result = {}
    for path in sorted(directory.glob("*.jsonl.gz")):
        rows = read_jsonl(path)
        trial = rows[0]["configuration"]["trial"]
        if trial in result:
            raise ValueError("Duplicate trial identity")
        result[trial] = (path, rows)
    if set(result) != set(range(1, 11)):
        raise ValueError("Exactly ten independent trials 1..10 required")
    if len({rows[0]["run_id"] for _, rows in result.values()}) != 10:
        raise ValueError("Duplicate run identity")
    return result


def coverage(rows):
    requested = next(row["t_ns"] for row in rows if row.get("name") == "present.requested")
    frames = [row for row in rows if row["type"] == "frame"]
    return {"first_ms": (frames[0]["t_ns"] - requested) / 1e6,
            "last_ms": (frames[-1]["t_ns"] - requested) / 1e6,
            "frames": len(frames)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("native")
    parser.add_argument("candidate")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    profile = ROOT / "measurement/profiles/programmatic-geometry.json"
    config = json.loads(profile.read_text())
    native, candidate = inventory(ROOT / args.native), inventory(ROOT / args.candidate)
    output = ROOT / args.output
    if output.exists():
        raise ValueError("Immutable report already exists")
    report = {
        "schema_version": 1, "proof_scope": "runtime_timing_diagnostic_not_native_parity",
        "split": "training", "verdict": "FAIL", "parity_proven": False,
        "analyzer_sha256": digest(ROOT / "analysis/compare.py"),
        "profile": {"path": str(profile.relative_to(ROOT)), "sha256": digest(profile)},
        "phase_policy": "Same unchanged profile/limits; observed event windows; no trimming gaps or fitting clocks",
        "pairs": [],
    }
    phases = {
        "opening": ("present.requested", 0, "present.completed", 0),
        "medium_to_large": ("detent.requested", 0, "detent.requested", 1),
        "large_to_medium": ("detent.requested", 1, "dismiss.requested", 0),
        "dismissal": ("dismiss.requested", 0, "dismiss.completed", 0),
    }
    for trial in range(1, 11):
        np, n = native[trial]
        cp, c = candidate[trial]
        pair = {"trial": trial, "artifacts": {
            "native": {"path": str(np.relative_to(ROOT)), "sha256": digest(np), "run_id": n[0]["run_id"]},
            "candidate": {"path": str(cp.relative_to(ROOT)), "sha256": digest(cp), "run_id": c[0]["run_id"]}},
            "structural_compatibility": {key: schema_equal(n[0][key], c[0][key])
                for key in ("scenario_id", "os", "device", "environment", "configuration")},
            "frame_coverage": {"native": coverage(n), "candidate": coverage(c)},
            "whole_trace": compare({"native": n, "candidate": c, "config": config}),
            "phases": {},
        }
        for name, (start, so, end, eo) in phases.items():
            cfg = {**config, "window": {"start_event": start, "start_occurrence": so,
                                        "end_event": end, "end_occurrence": eo}}
            pair["phases"][name] = compare({"native": n, "candidate": c, "config": cfg})
        report["pairs"].append(pair)
    timing = {}
    for pair in report["pairs"]:
        for name, value in pair["whole_trace"]["event_timing"].items():
            timing.setdefault(name, []).append(value["error_ms"])
    report["summary"] = {
        "pairs": 10,
        "structurally_compatible_pairs": sum(all(p["structural_compatibility"].values()) for p in report["pairs"]),
        "whole_trace_passes": sum(p["whole_trace"]["verdict"] == "PASS" for p in report["pairs"]),
        "leading_coverage_failures": sum(p["frame_coverage"]["candidate"]["first_ms"] > p["frame_coverage"]["native"]["first_ms"] for p in report["pairs"]),
        "tail_coverage_failures": sum(p["frame_coverage"]["candidate"]["last_ms"] < p["frame_coverage"]["native"]["last_ms"] for p in report["pairs"]),
        "event_error_ms": {name: {"min": min(values), "median": statistics.median(values), "max": max(values)}
                           for name, values in timing.items()},
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    print(json.dumps(report["summary"], indent=2))


if __name__ == "__main__":
    main()
