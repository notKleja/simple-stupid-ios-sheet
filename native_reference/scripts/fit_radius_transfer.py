#!/usr/bin/env python3
"""Fit model-only radius transfer candidates from two sealed OS cohorts."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

from evidence_contract import finite, require
from geometry_cohort import validate_manifest
from radius_transfer import fit_four

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_samples(manifest_path):
    manifest = json.loads(manifest_path.read_text())
    # Revalidate every compressed/raw hash, identity, source pin, and cohort
    # before using any frame as a fit input.
    summary = validate_manifest(manifest, ROOT)
    samples = []
    for entry in manifest["entries"]:
        raw = gzip.decompress((ROOT / entry["path"]).read_bytes())
        rows = [json.loads(line) for line in raw.splitlines()]
        head = rows[0]
        trial = head["configuration"]["trial"]
        screen = head["device"]["logical_size"]
        previous_top = None
        for row in rows:
            if row.get("type") != "frame" or not row.get("geometry_probe"):
                continue
            candidate = next(
                (item for item in row["geometry_probe"]["sheet_candidates"] if item.get("id") == "sheet"),
                None,
            )
            if not candidate:
                continue
            rect = candidate.get("model_window_rect", {})
            radii = candidate.get("effective_radii_model", {})
            required = (rect.get("x"), rect.get("y"), rect.get("width"), rect.get("height"))
            if not all(finite(value) for value in required):
                continue
            top = rect["y"]
            direction = "stationary"
            if previous_top is not None:
                if top < previous_top - 1e-9:
                    direction = "expanding"
                elif top > previous_top + 1e-9:
                    direction = "collapsing"
            previous_top = top
            samples.append(
                {
                    "trial": trial,
                    "features": {
                        "height": rect["height"],
                        "width": rect["width"],
                        "top": top,
                        "bottom_inset": screen["height"] - (top + rect["height"]),
                        "side_inset": min(rect["x"], screen["width"] - (rect["x"] + rect["width"])),
                        "detent": row.get("state", {}).get("selected_detent") or "none",
                        "direction": direction,
                    },
                    "radii": radii,
                }
            )
    require({sample["trial"] for sample in samples} == set(range(1, 11)), "fit extraction lost trials")
    return manifest, summary, samples


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("manifests", nargs=2)
    parser.add_argument("--output", default="native_reference/radius_transfer.json")
    args = parser.parse_args()
    profiles = {}
    inputs = []
    for name in args.manifests:
        path = ROOT / name
        manifest, summary, samples = load_samples(path)
        major = str(summary["session"]["os"]["version"]).split(".")[0]
        require(major not in profiles, "one sealed cohort per OS major required")
        profiles[major] = {
            "os": summary["session"]["os"],
            "device": summary["session"]["device"],
            "sample_count": len(samples),
            "corners": fit_four(samples),
        }
        inputs.append(
            {
                "path": name,
                "sha256": digest(path),
                "source_hashes": manifest["source_hashes"],
                "trials": list(range(1, 11)),
            }
        )
    require(set(profiles) == {"26", "27"}, "separate iOS26/iOS27 cohorts required")
    result = {
        "schema_version": 1,
        "capability_status": "measured_model_radius_transfer_contour_unresolved",
        "inputs": inputs,
        "profiles": profiles,
        "selection": {"training_trials": list(range(1, 9)), "holdout_trials": [9, 10], "holdout_limit_pt": 0.5},
        "rendered_contour_accepted": False,
        "scalar_radius_accepted": False,
        "flutter_parity_proven": False,
        "limits": [
            "Model/configuration radii only; not presentation-layer contour",
            "No extrapolation outside each reported training domain",
            "Private class names and timestamps are not fit inputs",
        ],
    }
    output = ROOT / args.output
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"output": str(output), "profiles": sorted(profiles), "statuses": {os: {corner: value["status"] for corner, value in profile["corners"].items()} for os, profile in profiles.items()}}))


if __name__ == "__main__":
    main()
