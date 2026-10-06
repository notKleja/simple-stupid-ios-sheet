#!/usr/bin/env python3
"""Bind unchanged native baseline attempts; QC is not motion acceptance."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "native_reference/scripts"))
from evidence_contract import read, validate_cohort  # noqa: E402


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory")
    parser.add_argument("--attempt", type=int, required=True)
    args = parser.parse_args()
    directory = ROOT / args.directory
    target = directory / "manifest.json"
    if target.exists():
        raise ValueError("Immutable native baseline manifest already exists")
    files = sorted(directory.glob("*.jsonl.gz"))
    runs = [read(path) for path in files]
    try:
        validate_cohort(runs)
        qc = {"verdict": "PASS", "scope": "ten-trial integrity and resting geometry only"}
    except ValueError as error:
        qc = {"verdict": "FAIL", "reason": str(error)}
    if subprocess.check_output(["git", "diff", "HEAD", "--", "native_reference/NativeSheetHarness"], cwd=ROOT):
        raise ValueError("Baseline native source unexpectedly changed")
    manifest = {
        "schema_version": 1, "split": "training", "attempt": args.attempt,
        "proof_scope": "pre_correction_native_command_timer_baseline",
        "motion_accepted": False, "quality": qc,
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "source_sha256": {str(path.relative_to(ROOT)): sha(path) for path in sorted(
            (ROOT / "native_reference/NativeSheetHarness").glob("*.swift"))},
        "executable_sha256": sha(ROOT / "build/native/iphonesimulator/NativeSheetHarness.app/NativeSheetHarness"),
        "artifacts": [{"path": str(path.relative_to(ROOT)), "sha256": sha(path),
                       "trial": run[0]["configuration"]["trial"], "run_id": run[0]["run_id"],
                       "attempt": args.attempt, "split": "training"}
                      for path, run in zip(files, runs)],
    }
    target.write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"manifest": str(target), "quality": qc}))


if __name__ == "__main__":
    main()
