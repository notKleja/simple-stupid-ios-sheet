#!/usr/bin/env python3
"""Record-format and observability QC for a trace; never a parity comparison."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import sys

from compare import TraceError, finite, read_jsonl, validate


def inspect(records):
    header, frames, events = validate(records, records[0].get("implementation"))
    intervals = [(frames[i]["t_ns"] - frames[i - 1]["t_ns"]) / 1_000_000 for i in range(1, len(frames))]
    metrics = {}
    for name in sorted({key for frame in frames for key in frame["metrics"]}):
        observed = sum(finite(frame["metrics"].get(name)) for frame in frames)
        reasons = sorted({frame.get("unavailable", {}).get(name) for frame in frames if frame.get("unavailable", {}).get(name)})
        metrics[name] = {"observed": observed, "missing": len(frames) - observed, "unavailable_reasons": reasons}
    hz = header["device"]["refresh_hz"]
    return {"status": "valid_record_format", "proof_scope": "ingestion_qc_only", "parity_proven": False,
            "run_id": header["run_id"], "scenario_id": header["scenario_id"], "evidence_kind": header["evidence_kind"],
            "os": header["os"], "device": header["device"], "frames": len(frames), "events": len(events),
            "event_names": sorted({event["name"] for event in events}), "metrics": metrics,
            "frame_intervals_ms": {"min": min(intervals), "median": statistics.median(intervals), "max": max(intervals)},
            "gaps_above_two_declared_frames": None if not finite(hz) or hz <= 0 else sum(dt > 2000 / hz for dt in intervals),
            "limitations": ["callback cadence is not proof of display presentation or dropped frames", "observed fields are not yet independently calibrated"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?")
    parser.add_argument("--request-stdin", action="store_true")
    args = parser.parse_args()
    try:
        records = json.load(sys.stdin) if args.request_stdin else read_jsonl(args.path)
        result = inspect(records)
        if not args.request_stdin:
            result["artifact"] = {"path": args.path, "sha256": hashlib.sha256(Path(args.path).read_bytes()).hexdigest()}
    except (OSError, ValueError, TypeError, KeyError, IndexError, AttributeError) as error:
        result = {"status": "invalid_record_format", "issues": [str(error)], "parity_proven": False}
    print(json.dumps(result, allow_nan=False, indent=2))
    return 0 if result["status"] == "valid_record_format" else 1


if __name__ == "__main__":
    sys.exit(main())
