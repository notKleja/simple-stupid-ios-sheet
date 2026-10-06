#!/usr/bin/env python3
"""Summarize native programmatic resting windows; no Flutter/parity inference."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import statistics
from evidence_contract import read, validate_cohort, LEGACY_ADAPTER

def main():
    p = argparse.ArgumentParser()
    p.add_argument("directories", nargs="+")
    p.add_argument("--output", required=True)
    p.add_argument("--legacy-adapter", choices=[LEGACY_ADAPTER])
    a = p.parse_args()
    report = {"method": "median of samples in last 0.4s before next requested boundary; no curve fitting", "profiles": []}
    for directory in map(Path, a.directories):
        files = sorted(directory.glob("*.jsonl*"))
        raw_runs = [read(f) for f in files]
        checked = validate_cohort(raw_runs, a.legacy_adapter)
        runs = [rows for rows, _ in checked]
        profile = {"trace_count": len(runs), "session": raw_runs[0][0], "artifacts": [], "rest": {}, "acceptance": "resting_geometry_only"}
        if raw_runs[0][0].get("native_contract_version", 1) == 1:
            profile["legacy_adapter"] = a.legacy_adapter
            profile["adapter_provenance"] = "ID/null-reason interpretation only; original bytes/hashes retained; no new observation inferred"
        for path in files:
            profile["artifacts"].append({"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        for phase, next_name, occurrence in [("medium_initial", "detent.requested", 0), ("large", "detent.requested", 1), ("medium_return", "dismiss.requested", 0)]:
            samples = {}
            for run, (_, windows) in zip(runs, checked):
                frames = windows[phase]
                for key in set().union(*(r["metrics"] for r in frames)):
                    values = [r["metrics"][key] for r in frames if r["metrics"].get(key) is not None]
                    if values:
                        samples.setdefault(key, []).append(statistics.median(values))
            profile["rest"][phase] = {key: {"median": statistics.median(v), "min": min(v), "max": max(v), "stddev": statistics.pstdev(v), "trials": len(v)} for key, v in samples.items()}
        resolved = [r["data"] for run in runs for r in run if r.get("name") == "detent.resolved"]
        profile["resolved_detents"] = {key: sorted(set(r[key] for r in resolved if r.get(key) is not None)) for key in ["maximum", "medium", "large", "fixed"]}
        frames = [r for run in runs for r in run if r["type"] == "frame"]
        profile["quality"] = {"frame_count": len(frames), "geometry_unavailable_frames": sum(r["metrics"].get("sheet.y") is None for r in frames),
            "geometry_sources": sorted(set(r.get("geometry_source", "legacy_mixed_tree_conversion") for r in frames))}
        animations = {json.dumps(a, sort_keys=True) for r in frames for l in r.get("raw_layers", []) for a in l.get("animations", [])}
        profile["observed_animation_objects"] = [json.loads(a) for a in sorted(animations)]
        profile["unresolved"] = ["scalar visible radius", "effective barrier alpha", "gesture transfer", "snap policy", "scroll handoff", "actual background touch", "settling detector", "stacking", "keyboard", "OS-wide/device-independent formulas"]
        report["profiles"].append(profile)
    Path(a.output).write_text(json.dumps(report, indent=2) + "\n")
    for profile in report["profiles"]:
        print(json.dumps({"os": profile["session"]["os"], "device": profile["session"]["device"], "resolved": profile["resolved_detents"], "medium": {k:v for k,v in profile["rest"]["medium_initial"].items() if k in ["sheet.x", "sheet.y", "sheet.width", "sheet.height", "sheet.bottom_inset"]}, "large": {k:v for k,v in profile["rest"]["large"].items() if k in ["sheet.x", "sheet.y", "sheet.width", "sheet.height", "sheet.bottom_inset"]}}))

if __name__ == "__main__":
    main()
