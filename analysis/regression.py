#!/usr/bin/env python3
"""Fail-closed trace-pair regression coverage. Unavailable cells remain unresolved."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import sys

from compare import TraceError, compare, read_jsonl, require


def cells(matrix):
    require(matrix.get("schema_version") == 1, "unsupported matrix schema")
    axes = matrix["environment_axes"]
    require(all(isinstance(axes.get(key), list) and axes[key] for key in ("ios_major", "device_geometry", "orientation")), "nonempty environment axes required")
    require(isinstance(matrix.get("cases"), list) and matrix["cases"], "nonempty cases required")
    result = {}
    for os_major, geometry, orientation, case in itertools.product(axes["ios_major"], axes["device_geometry"], axes["orientation"], matrix["cases"]):
        cell_id = f"{os_major}/{geometry}/{orientation}/{case['id']}"
        require(cell_id not in result, "duplicate matrix cell")
        result[cell_id] = {"ios_major": os_major, "device_geometry": geometry, "orientation": orientation, **case}
    return result


def entry_request(entry, base):
    if "native" in entry:
        return {"native": entry["native"], "candidate": entry["candidate"], "config": entry["config"]}
    result = {}
    artifacts = {}
    for name in ("native", "candidate", "config", "recipe"):
        path = base / entry[name + "_path"]
        data = path.read_bytes()
        artifacts[name] = {"path": str(path), "sha256": hashlib.sha256(data).hexdigest()}
        if name in ("native", "candidate"):
            result[name] = read_jsonl(path)
        elif name == "config":
            result[name] = json.loads(data)
        else:
            recipe = json.loads(data)
            require(recipe.get("schema_version") == 1, "unsupported recipe")
            result["recipe"] = recipe
        if name + "_sha256" in entry:
            require(artifacts[name]["sha256"] == entry[name + "_sha256"], f"{name} artifact hash mismatch")
    result["artifacts"] = artifacts
    return result


def run(request, base=Path(".")):
    result = {"schema_version": 1, "verdict": "FAIL", "proof_scope": "trace_pair_regression_coverage",
              "parity_proven": False, "accepted_pairs": 0, "issues": [], "pairs": [], "coverage": {}}
    try:
        expected = cells(request["matrix"])
        repeats = request["matrix"].get("minimum_trials", 10)
        require(isinstance(repeats, int) and repeats > 0, "positive minimum_trials required")
        result["required_cells"] = len(expected)
        coverage = {cell_id: set() for cell_id in expected}
        seen_trials, seen_native, seen_candidate = set(), set(), set()
        geometry_sizes = {}
        for entry in request.get("entries", []):
            pair = {"cell_id": entry.get("cell_id"), "trial": entry.get("trial"), "verdict": "FAIL"}
            result["pairs"].append(pair)
            try:
                cell_id, trial = entry["cell_id"], entry["trial"]
                require(cell_id in expected, "unknown matrix cell")
                require(isinstance(trial, int) and not isinstance(trial, bool) and trial >= 0, "integer trial required")
                identity = (cell_id, trial)
                require(identity not in seen_trials, "duplicate cell/trial")
                seen_trials.add(identity)
                payload = entry_request(entry, base)
                report = compare(payload)
                pair["report"] = report
                nh, ch = payload["native"][0], payload["candidate"][0]
                require(nh.get("evidence_kind") == ch.get("evidence_kind") == "runtime", "synthetic evidence cannot satisfy runtime coverage")
                require(nh["run_id"] not in seen_native and ch["run_id"] not in seen_candidate, "duplicate/reused run ID cannot pad independent trials")
                seen_native.add(nh["run_id"])
                seen_candidate.add(ch["run_id"])
                cell = expected[cell_id]
                require(nh["scenario_id"] == cell["scenario_id"], "scenario does not match matrix case")
                require(int(nh["os"]["version"].split(".")[0]) == cell["ios_major"], "OS does not match cell")
                require(nh["environment"]["orientation"] == cell["orientation"], "orientation does not match cell")
                size = nh["device"]["logical_size"]
                # Portrait-equivalent dimensions keep the same geometry identity across orientation.
                size_key = tuple(sorted((size["width"], size["height"])))
                geometry = cell["device_geometry"]
                require(geometry not in geometry_sizes or geometry_sizes[geometry] == size_key, "geometry binding changed across cells")
                require(all(name == geometry or bound != size_key for name, bound in geometry_sizes.items()), "two geometry roles cannot bind to the same logical display size")
                geometry_sizes[geometry] = size_key
                require("recipe" in payload and "artifacts" in payload, "recipe and hashed artifact provenance required for runtime coverage")
                require(payload["recipe"]["scenario_id"] == cell["scenario_id"] and payload["recipe"].get("role") == cell["role"], "recipe scenario/training/holdout mismatch")
                if cell["role"] == "holdout":
                    require(entry.get("recipe_sha256") == payload["artifacts"]["recipe"]["sha256"], "holdout must reference its frozen recipe hash")
                require(report["verdict"] == "PASS" and report["native_parity_eligible"], "runtime pair comparison did not pass")
                require(entry.get("runtime_input_verified") is True, "actual delivered recipe input verification required")
                pair["artifacts"] = payload["artifacts"]
                pair["verdict"] = "PASS"
                coverage[cell_id].add(trial)
                result["accepted_pairs"] += 1
            except (TraceError, OSError, KeyError, ValueError, TypeError, IndexError) as error:
                pair["issues"] = [str(error)]
                result["issues"].append(f"{entry.get('cell_id')}: {error}")
        result["geometry_bindings"] = {key: list(value) for key, value in geometry_sizes.items()}
        for cell_id, trials in coverage.items():
            result["coverage"][cell_id] = {"accepted_trials": len(trials), "required_trials": repeats, "role": expected[cell_id]["role"],
                                           "status": "PASS" if len(trials) >= repeats else "UNRESOLVED"}
        result["unresolved_cells"] = sum(len(trials) < repeats for trials in coverage.values())
        result["verdict"] = "PASS" if not result["issues"] and result["unresolved_cells"] == 0 else "FAIL"
        result["limitations"] = ["PASS covers configured trace-pair cells only", "macro-case subconditions, contour geometry, physical touch delivery and device provenance require independent evidence", "overall acceptance belongs to the master after builds, runtime and holdouts"]
    except (TraceError, KeyError, TypeError, ValueError) as error:
        result["issues"].append(str(error))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", nargs="?")
    parser.add_argument("--matrix", default="spec/test_matrix.json")
    parser.add_argument("--request-stdin", action="store_true")
    args = parser.parse_args()
    try:
        if args.request_stdin:
            result = run(json.load(sys.stdin))
        else:
            require(bool(args.manifest), "manifest path required")
            manifest = json.loads(Path(args.manifest).read_text())
            manifest["matrix"] = json.loads(Path(args.matrix).read_text())
            result = run(manifest, Path(args.manifest).resolve().parent)
    except (OSError, ValueError, TypeError, KeyError) as error:
        result = {"verdict": "FAIL", "issues": [str(error)], "parity_proven": False}
    print(json.dumps(result, allow_nan=False, indent=2))
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
