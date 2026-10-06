#!/usr/bin/env python3
"""Download only complete native research traces through the guest file API."""
import argparse
import base64
import gzip
import json
from pathlib import Path
import subprocess
from vphone_run import rpc, ROOT

def main():
    p = argparse.ArgumentParser()
    p.add_argument("machine")
    p.add_argument("--output", required=True)
    a = p.parse_args()
    inventory = json.loads(subprocess.check_output(["vphone-launchpad-cli", "vm", "list"], text=True))
    machine = next(m for m in inventory if m["name"] == a.machine)
    control = machine["controlSocket"]
    data = rpc(control, "apps.data_dir", {"bundle_id": "dev.notkleja.NativeSheetHarness"})["data_path"]
    files = rpc(control, "files.list", {"path": data + "/Documents"})["entries"]
    out = ROOT / a.output
    out.mkdir(parents=True, exist_ok=True)
    count = 0
    for entry in files:
        if not entry["name"].endswith(".jsonl"):
            continue
        reply = rpc(control, "files.read", {"path": entry["path"], "binary": True, "limit": 64_000_000})
        if reply.get("truncated"):
            raise RuntimeError("Guest trace download was truncated")
        raw = base64.b64decode(reply["content"])
        rows = [json.loads(l) for l in raw.splitlines()]
        if not any(r.get("name") == "dismiss.completed" for r in rows):
            continue
        with gzip.open(out / (entry["name"] + ".gz"), "wb") as f:
            f.write(raw)
        count += 1
    (out / "vphone_inventory.json").write_text(json.dumps(machine, indent=2) + "\n")
    print(json.dumps({"complete_traces": count, "output": str(out)}))
    if count < 10:
        raise RuntimeError("Expected at least ten completed trials")

if __name__ == "__main__":
    main()
