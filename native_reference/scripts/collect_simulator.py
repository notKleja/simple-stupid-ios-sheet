#!/usr/bin/env python3
"""Run one deterministic scenario; archive only completed runtime trace batches."""
import argparse
import gzip
import json
import os
from pathlib import Path
import subprocess
import time

BUNDLE = "dev.notkleja.NativeSheetHarness"
ROOT = Path(__file__).resolve().parents[2]

def sim(*args, env=None):
    return subprocess.check_output(["xcrun", "simctl", *args], text=True, env=env).strip()

def main():
    p = argparse.ArgumentParser()
    p.add_argument("udid")
    p.add_argument("--scenario", default="native.medium_large.programmatic")
    p.add_argument("--trials", type=int, default=10)
    p.add_argument("--output", required=True)
    a = p.parse_args()
    inventory = json.loads(sim("list", "-j"))
    runtime_id = next(k for k, v in inventory["devices"].items() if any(d["udid"] == a.udid for d in v))
    runtime = next(r for r in inventory["runtimes"] if r["identifier"] == runtime_id)
    sim("bootstatus", a.udid, "-b")
    subprocess.run(["xcrun", "simctl", "terminate", a.udid, BUNDLE], capture_output=True)
    sim("install", a.udid, str(ROOT / "build/native/iphonesimulator/NativeSheetHarness.app"))
    container = Path(sim("get_app_container", a.udid, BUNDLE, "data")) / "Documents"
    old = set(container.glob("*.jsonl"))
    env = dict(os.environ, SIMCTL_CHILD_NATIVE_AUTORUN="1", SIMCTL_CHILD_NATIVE_TRIALS=str(a.trials),
               SIMCTL_CHILD_NATIVE_SCENARIO=a.scenario, SIMCTL_CHILD_NATIVE_OS_BUILD=runtime["buildversion"])
    print(sim("launch", a.udid, BUNDLE, env=env), flush=True)
    deadline = time.monotonic() + max(90, a.trials * 9)
    while time.monotonic() < deadline:
        fresh = set(container.glob("*.jsonl")) - old
        if len(fresh) >= a.trials and any('"batch.completed"' in f.read_text()[-500:] for f in fresh):
            break
        time.sleep(1)
    else:
        raise RuntimeError("No completed batch; refuse to archive partial trials")
    out = ROOT / a.output
    out.mkdir(parents=True, exist_ok=True)
    (out / "runtime_inventory.json").write_text(json.dumps(runtime, indent=2) + "\n")
    for path in sorted(fresh):
        rows = [json.loads(s) for s in path.read_text().splitlines()]
        assert any(r.get("name") == "dismiss.completed" for r in rows), path
        assert rows[0]["os"]["build"] == runtime["buildversion"]
        with gzip.open(out / (path.name + ".gz"), "wb") as dest:
            dest.write(path.read_bytes())
    print(json.dumps({"traces": len(fresh), "output": str(out), "runtime": runtime["version"]}), flush=True)

if __name__ == "__main__":
    main()
