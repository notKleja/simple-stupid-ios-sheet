#!/usr/bin/env python3
"""Archive fresh runtime bytes, including incomplete attempts; never synthesize rows."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
BUNDLE = "dev.sheetreference.iosSheetCandidate"


def sim(*args, env=None):
    return subprocess.check_output(["xcrun", "simctl", *args], text=True, env=env).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("udid")
    parser.add_argument("--app", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--attempt", type=int, required=True)
    parser.add_argument("--trials", type=int, default=10)
    args = parser.parse_args()
    output = ROOT / args.output
    if output.exists():
        raise RuntimeError("Immutable attempt directory already exists")
    inventory = json.loads(sim("list", "-j"))
    runtime_id = next(k for k, v in inventory["devices"].items()
                      if any(d["udid"] == args.udid for d in v))
    runtime = next(r for r in inventory["runtimes"] if r["identifier"] == runtime_id)
    app = Path(args.app).resolve()
    sim("bootstatus", args.udid, "-b")
    subprocess.run(["xcrun", "simctl", "terminate", args.udid, BUNDLE], capture_output=True)
    sim("install", args.udid, str(app))
    documents = Path(sim("get_app_container", args.udid, BUNDLE, "data")) / "Documents"
    old = set(documents.glob("*.jsonl"))
    env = dict(os.environ, SIMCTL_CHILD_SHEET_OS_BUILD=runtime["buildversion"])
    print(sim("launch", args.udid, BUNDLE, env=env), flush=True)
    deadline = time.monotonic() + max(90, args.trials * 9)
    complete = False
    while time.monotonic() < deadline:
        fresh = sorted(set(documents.glob("*.jsonl")) - old)
        rows = [[json.loads(line) for line in path.read_text().splitlines()] for path in fresh]
        complete = len(rows) == args.trials and all(
            run[-1].get("name") == "dismiss.completed" and run[-1].get("terminal") is True
            for run in rows)
        if complete:
            break
        time.sleep(1)
    output.mkdir(parents=True)
    manifest = {
        "schema_version": 1, "proof_scope": "runtime_candidate_attempt_not_parity",
        "split": "training", "attempt": args.attempt, "udid": args.udid,
        "runtime": runtime, "complete": complete, "expected_trials": args.trials,
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "source_worktree_diff_sha256": hashlib.sha256(subprocess.check_output(["git", "diff", "HEAD"], cwd=ROOT)).hexdigest(),
        "executable_sha256": hashlib.sha256((app / "Runner").read_bytes()).hexdigest(),
        "build_mode": "debug_simulator", "artifacts": [],
    }
    # Untracked new timing source is outside git diff; bind all candidate Dart files too.
    manifest["candidate_source_sha256"] = {
        str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted((ROOT / "flutter_reference/candidate/lib").glob("*.dart"))}
    for path, run in zip(fresh, rows):
        target = output / (path.name + ".gz")
        with gzip.GzipFile(filename=str(target), mode="wb", mtime=0) as dest:
            dest.write(path.read_bytes())
        manifest["artifacts"].append({
            "path": str(target.relative_to(ROOT)),
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
            "raw_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "trial": run[0]["configuration"]["trial"], "run_id": run[0]["run_id"],
            "attempt": args.attempt, "split": "training",
            "terminal": run[-1].get("name"), "rows": len(run),
        })
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"complete": complete, "traces": len(rows), "manifest": str(output / "manifest.json")}), flush=True)
    if not complete:
        raise RuntimeError("Partial attempt preserved; not eligible for paired acceptance")


if __name__ == "__main__":
    main()
