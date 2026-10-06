#!/usr/bin/env python3
"""Locate the known red footer in compositor pixels, independent of CALayer geometry."""
import argparse
import json
from pathlib import Path
import subprocess

def main():
    p = argparse.ArgumentParser()
    p.add_argument("video")
    p.add_argument("--output", required=True)
    a = p.parse_args()
    # iPhone 402pt width, 3x physical pixels. x=275pt avoids the center ruler.
    with Path(a.output).with_suffix(".ffmpeg.log").open("w") as log:
        data = subprocess.check_output(["ffmpeg", "-v", "error", "-i", a.video, "-vf", "crop=3:2622:825:0,scale=1:874:flags=neighbor", "-fps_mode", "passthrough", "-pix_fmt", "rgb24", "-f", "rawvideo", "-"], stderr=log)
    pts = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_frames", "-show_entries", "frame=best_effort_timestamp_time", "-of", "json", a.video]))["frames"]
    frames = []
    size = 874 * 3
    if len(data) // size != len(pts):
        raise RuntimeError("Decoded frames and source timestamps differ; refuse alignment")
    for i in range(len(data) // size):
        row = data[i * size:(i + 1) * size]
        red = [y for y in range(750, 874) if row[y*3] > 180 and row[y*3+1] < 70 and row[y*3+2] < 70]
        frames.append({"frame": i, "video_pts_s": float(pts[i]["best_effort_timestamp_time"]), "red_min_y": min(red) if red else None, "red_max_y": max(red) if red else None})
    report = {"method": "single physical x=825px sample column; nearest scaling to logical874; red r>180,g<70,b<70; scan750..873pt", "limitation": "Video and runtime clocks are not synchronized; variable compositor capture cadence cannot exclude an unsampled single display frame", "video": a.video,
              "frame_count": len(frames), "footer_above_820": [f for f in frames if f["red_min_y"] is not None and f["red_min_y"] < 820], "frames": frames}
    Path(a.output).write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"frames": len(frames), "footer_above_820": len(report["footer_above_820"])}))

if __name__ == "__main__":
    main()
