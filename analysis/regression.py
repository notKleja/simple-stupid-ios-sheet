#!/usr/bin/env python3
"""Fail-closed trace-pair regression coverage. Unavailable cells remain unresolved."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import sys

from compare import TraceError, compare, read_jsonl, require, finite, indexed_events, schema_equal


def normalize_window(window):
    require(isinstance(window, dict), "required check window must be an object")
    normalized = {}
    for side in ("start", "end"):
        event, occurrence = window.get(side + "_event"), window.get(side + "_occurrence", 0)
        require(isinstance(event, str) and event, "required check window needs explicit event boundaries")
        require(isinstance(occurrence, int) and not isinstance(occurrence, bool) and occurrence >= 0, "window occurrence must be a nonnegative integer")
        normalized[side + "_event"], normalized[side + "_occurrence"] = event, occurrence
    require((normalized["start_event"], normalized["start_occurrence"]) != (normalized["end_event"], normalized["end_occurrence"]), "required check window cannot be empty")
    return normalized


def required_checks(case):
    checks = case.get("required_checks")
    require(isinstance(checks, list) and checks, f"case {case.get('id')}: nonempty required_checks must declare all phases/subconditions")
    result = {}
    for check in checks:
        require(isinstance(check, dict) and isinstance(check.get("id"), str) and check["id"], "required check needs an ID")
        require(check["id"] not in result, "duplicate required check ID")
        parameters = check.get("parameters", {})
        require(isinstance(parameters, dict) and all(isinstance(key, str) and key and
                (isinstance(value, (str, bool)) or finite(value)) for key, value in parameters.items()), "subcondition parameters must be finite scalar controls")
        expected_events = check.get("expected_events", {})
        require(isinstance(expected_events, dict) and all(isinstance(name, str) and isinstance(fields, dict)
                and fields for name, fields in expected_events.items()), "expected event observations must be objects")
        result[check["id"]] = {**check, "window": normalize_window(check.get("window")), "parameters": parameters}
    # Every original matrix dimension is promoted to explicit check requirements;
    # no phase/check/variant can remain an unenforced prose-only promise.
    declared = case.get("coverage_dimensions", {})
    for name, values in declared.items():
        require(isinstance(values, list) and values, "coverage dimension must be nonempty")
        for value in values:
            require(any(schema_equal(check["parameters"].get(name), value) and name in check["parameters"]
                        for check in result.values()), f"required_checks omit subcondition {name}={value}")
    names = case.get("required_check_names", case.get("checks", [check.get("check", check["id"]) for check in result.values()]))
    require(isinstance(names, list) and names and all(isinstance(name, str) and name for name in names), "required_check_names must name all logical checks")
    promised = list(case.get("checks", []))
    if "interaction" in case:
        promised += ["present", "dismiss", case["interaction"]]
    require(all(name in names for name in promised), "required_check_names omit a declared case phase/check")
    for name in names:
        require(any(check.get("check", check["id"]) == name for check in result.values()), f"required_checks omit required check {name}")
    axes = list(declared)
    for values in itertools.product(*(declared[name] for name in axes)):
        combination = dict(zip(axes, values))
        for name in names:
            require(any(check.get("check", check["id"]) == name and all(key in check["parameters"]
                        and schema_equal(check["parameters"][key], value) for key, value in combination.items())
                        for check in result.values()), f"required_checks omit combination {combination} for {name}")
    return result


def cells(matrix):
    require(matrix.get("schema_version") == 1, "unsupported matrix schema")
    axes = matrix["environment_axes"]
    require(all(isinstance(axes.get(key), list) and axes[key] for key in ("ios_major", "device_geometry", "orientation")), "nonempty environment axes required")
    require(isinstance(matrix.get("cases"), list) and matrix["cases"], "nonempty cases required")
    result = {}
    for os_major, geometry, orientation, case in itertools.product(axes["ios_major"], axes["device_geometry"], axes["orientation"], matrix["cases"]):
        cell_id = f"{os_major}/{geometry}/{orientation}/{case['id']}"
        require(cell_id not in result, "duplicate matrix cell")
        result[cell_id] = {"ios_major": os_major, "device_geometry": geometry, "orientation": orientation, **case,
                           "check_contracts": required_checks(case)}
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
        coverage = {cell_id: {check_id: set() for check_id in cell["check_contracts"]} for cell_id, cell in expected.items()}
        seen_trials, seen_native, seen_candidate = set(), {}, {}
        geometry_sizes = {}
        for entry in request.get("entries", []):
            pair = {"cell_id": entry.get("cell_id"), "trial": entry.get("trial"), "check_id": entry.get("check_id"), "verdict": "FAIL"}
            result["pairs"].append(pair)
            try:
                cell_id, trial = entry["cell_id"], entry["trial"]
                require(cell_id in expected, "unknown matrix cell")
                require(isinstance(trial, int) and not isinstance(trial, bool) and trial >= 0, "integer trial required")
                cell = expected[cell_id]
                check_id = entry.get("check_id")
                require(check_id in cell["check_contracts"], "explicit known check_id required for full-case coverage")
                contract = cell["check_contracts"][check_id]
                identity = (cell_id, trial, check_id)
                require(identity not in seen_trials, "duplicate cell/trial/check")
                seen_trials.add(identity)
                payload = entry_request(entry, base)
                configured = payload["config"].get("window")
                require(configured is None or normalize_window(configured) == contract["window"], "caller window does not match required check window")
                payload["config"] = {**payload["config"], "window": contract["window"]}
                if contract.get("check", contract["id"]) == "model_radius":
                    require(payload["config"].get("check_family") == "model_radius",
                            "model-radius check cannot use a legacy scalar comparison")
                pair["required_window"] = contract["window"]
                report = compare(payload)
                pair["report"] = report
                nh, ch = payload["native"][0], payload["candidate"][0]
                require(nh.get("evidence_kind") == ch.get("evidence_kind") == "runtime", "synthetic evidence cannot satisfy runtime coverage")
                owner = (cell_id, trial)
                require(seen_native.get(nh["run_id"], owner) == owner and seen_candidate.get(ch["run_id"], owner) == owner,
                        "duplicate/reused run ID cannot pad independent trials")
                seen_native[nh["run_id"]], seen_candidate[ch["run_id"]] = owner, owner
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
                for header in (nh, ch):
                    observed = header["configuration"].get("measurement_parameters", {})
                    require(all(key in observed and schema_equal(observed[key], value) for key, value in contract["parameters"].items()),
                            "required subcondition not observed in run configuration")
                recipe_parameters = payload["recipe"].get("preconditions", {}).get("measurement_parameters", {})
                require(all(key in recipe_parameters and schema_equal(recipe_parameters[key], value) for key, value in contract["parameters"].items()),
                        "recipe does not pin required subcondition parameters")
                for role in ("native", "candidate"):
                    events = indexed_events([row for row in payload[role] if row["type"] == "event"])
                    for name, fields in contract.get("expected_events", {}).items():
                        require(name in events and all(key in events[name]["data"] and schema_equal(events[name]["data"][key], value)
                                for key, value in fields.items()), "required check action/outcome event not observed")
                if cell["role"] == "holdout":
                    require(entry.get("recipe_sha256") == payload["artifacts"]["recipe"]["sha256"], "holdout must reference its frozen recipe hash")
                require(report["verdict"] == "PASS" and report["native_parity_eligible"], "runtime pair comparison did not pass")
                require(entry.get("runtime_input_verified") is True, "actual delivered recipe input verification required")
                pair["artifacts"] = payload["artifacts"]
                pair["verdict"] = "PASS"
                coverage[cell_id][check_id].add(trial)
                result["accepted_pairs"] += 1
            except (TraceError, OSError, KeyError, ValueError, TypeError, IndexError) as error:
                pair["issues"] = [str(error)]
                result["issues"].append(f"{entry.get('cell_id')}: {error}")
        result["geometry_bindings"] = {key: list(value) for key, value in geometry_sizes.items()}
        for cell_id, checks in coverage.items():
            complete_trials = set.intersection(*checks.values())
            passed = len(complete_trials) >= repeats
            result["coverage"][cell_id] = {"accepted_trials": len(complete_trials), "required_trials": repeats, "role": expected[cell_id]["role"],
                                           "status": "PASS" if passed else "PARTIAL" if any(checks.values()) else "UNRESOLVED",
                                           "checks": {check_id: {"accepted_trials": len(trials), "required_trials": repeats,
                                                     "status": "PASS" if len(trials) >= repeats else "UNRESOLVED"} for check_id, trials in checks.items()}}
        result["required_checks"] = sum(len(checks) for checks in coverage.values())
        result["unresolved_cells"] = sum(cell["status"] != "PASS" for cell in result["coverage"].values())
        result["verdict"] = "PASS" if not result["issues"] and result["unresolved_cells"] == 0 else "FAIL"
        result["limitations"] = ["PASS requires every declared phase/subcondition/check within each independent trial", "contour calibration and actual physical touch delivery still require independent evidence", "overall acceptance belongs to the master after builds, runtime and holdouts"]
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
            result["matrix_artifact"] = {"path": str(Path(args.matrix).resolve()), "sha256": hashlib.sha256(Path(args.matrix).read_bytes()).hexdigest()}
    except (OSError, ValueError, TypeError, KeyError) as error:
        result = {"verdict": "FAIL", "issues": [str(error)], "parity_proven": False}
    print(json.dumps(result, allow_nan=False, indent=2))
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
