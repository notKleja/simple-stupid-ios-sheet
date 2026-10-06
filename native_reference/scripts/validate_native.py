#!/usr/bin/env python3
"""Fail-closed native evidence integrity, not full native parity."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from evidence_contract import read, require, validate_cohort

ROOT = Path(__file__).resolve().parents[2]

def validate_manifest(manifest, root=ROOT):
    require(isinstance(manifest.get("profiles"), list) and manifest["profiles"], "nonempty accepted profiles required")
    total = gaps = 0
    seen_runs, seen_paths = set(), set()
    for profile in manifest["profiles"]:
        artifacts = profile["artifacts"]
        require(type(profile.get("trace_count")) is int and profile["trace_count"] == len(artifacts) == 10, "declared count must equal exactly ten artifacts")
        raw = []
        for artifact in artifacts:
            path = (root / artifact["path"]).resolve()
            require(path not in seen_paths, "artifact reused across accepted profiles")
            seen_paths.add(path)
            require(hashlib.sha256(path.read_bytes()).hexdigest() == artifact["sha256"], "source artifact hash mismatch")
            raw.append(read(path))
        require(profile["session"] == raw[0][0], "declared first session does not match hashed artifact")
        for rows, windows in validate_cohort(raw, profile.get("legacy_adapter")):
            require(rows[0]["run_id"] not in seen_runs, "run reused across accepted profiles")
            seen_runs.add(rows[0]["run_id"])
            gaps += sum(row["type"] == "frame" and row["metrics"].get("sheet.y") is None for row in rows)
            total += 1
    return {"accepted_trace_files": total, "profiles": len(manifest["profiles"]), "explicit_geometry_gaps": gaps,
            "integrity": "PASS", "full_geometry_parity": "unresolved"}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", default=str(ROOT / "native_reference/measurements.json"))
    args = parser.parse_args()
    try:
        result = validate_manifest(json.loads(Path(args.manifest).read_text()))
    except (ValueError, KeyError, TypeError, OSError) as error:
        result = {"integrity": "FAIL", "issues": [str(error)], "full_geometry_parity": "unresolved"}
    print(json.dumps(result))
    return 0 if result["integrity"] == "PASS" else 1

if __name__ == "__main__":
    sys.exit(main())
