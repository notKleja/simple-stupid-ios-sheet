#!/usr/bin/env python3
"""Install the research app over the documented guest RPC, then launch by URL."""
import argparse
import base64
import json
from pathlib import Path
import socket
import subprocess

ROOT = Path(__file__).resolve().parents[2]

def rpc(sockpath, method, params):
    with socket.socket(socket.AF_UNIX) as conn:
        conn.settimeout(90)
        conn.connect(sockpath)
        conn.sendall((json.dumps({"t": "rpc", "method": method, "params": params}) + "\n").encode())
        reply = b""
        while b"\n" not in reply:
            chunk = conn.recv(65536)
            if not chunk:
                break
            reply += chunk
    result = json.loads(reply)
    if not result.get("ok"):
        raise RuntimeError(result)
    return result.get("result", {})

def main():
    p = argparse.ArgumentParser()
    p.add_argument("machine")
    p.add_argument("--scenario", default="native.medium_large.programmatic")
    p.add_argument("--trials", type=int, default=10)
    p.add_argument("--install", action="store_true")
    a = p.parse_args()
    inventory = json.loads(subprocess.check_output(["vphone-launchpad-cli", "vm", "list"], text=True))
    machine = next(m for m in inventory if m["name"] == a.machine)
    control = machine["controlSocket"]
    if a.install:
        data = (ROOT / "build/native/NativeSheetHarness.ipa").read_bytes()
        if len(data) > 500_000:
            raise RuntimeError("Small-file RPC budget exceeded; use streaming API")
        uploaded = rpc(control, "files.write", {"path": "/private/var/tmp/NativeSheetHarness.ipa",
                        "content": base64.b64encode(data).decode(), "encoding": "base64"})
        print(json.dumps({"upload": uploaded}), flush=True)
        print(json.dumps({"install": rpc(control, "apps.install", {"path": "/private/var/tmp/NativeSheetHarness.ipa"})}), flush=True)
    url = f"nativesheet://run?scenario={a.scenario}&trials={a.trials}"
    print(json.dumps({"launch": rpc(control, "apps.launch", {"bundle_id": "dev.notkleja.NativeSheetHarness", "url": url})}), flush=True)
    print(json.dumps({"foreground": rpc(control, "apps.foreground", {})}), flush=True)
    print(json.dumps({"data": rpc(control, "apps.data_dir", {"bundle_id": "dev.notkleja.NativeSheetHarness"})}), flush=True)

if __name__ == "__main__":
    main()
