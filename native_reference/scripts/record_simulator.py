#!/usr/bin/env python3
"""Capture compositor video alongside a fresh deterministic native trace batch."""
import argparse
from pathlib import Path
import signal
import subprocess
from vphone_run import ROOT

def main():
    p = argparse.ArgumentParser()
    p.add_argument("udid")
    p.add_argument("--output", required=True)
    p.add_argument("--trials", type=int, default=10)
    a = p.parse_args()
    out = ROOT / a.output
    out.mkdir(parents=True, exist_ok=True)
    with (out / "video_capture.log").open("w") as log:
        recorder = subprocess.Popen(["xcrun", "simctl", "io", a.udid, "recordVideo", "--codec=h264", str(out / "native-rendering.mp4")], stdout=log, stderr=log)
        try:
            subprocess.run(["python3", str(Path(__file__).with_name("collect_simulator.py")), a.udid, "--trials", str(a.trials), "--output", a.output], check=True)
        finally:
            recorder.send_signal(signal.SIGINT)
            recorder.wait(timeout=20)
    subprocess.run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(out / "native-rendering.mp4")], stdout=(out / "video_metadata.json").open("w"), check=True)

if __name__ == "__main__":
    main()
