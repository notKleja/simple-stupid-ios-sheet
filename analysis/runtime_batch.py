#!/usr/bin/env python3
"""Manifest-hashed canonical v2 pairing; never edits traces or analyzer gates."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import sys

from compare import TraceError, compare, read_jsonl, require, schema_equal, validate
from regression import cells, normalize_window

SPLITS = ("diagnostic", "training", "holdout")
CONFIG_KEYS = {"trial", "detents", "surface", "grabber", "page_sizing", "modal_in_presentation", "largest_undimmed",
               "presentation_style", "preferred_content_size", "placement", "edge_attached_in_compact_height",
               "width_follows_preferred_content_size", "scroll_expansion"}
PROGRAMMATIC_EVENTS = ["present.requested", "present.first_visible", "present.completed", "detent.requested", "detent.requested",
                       "dismiss.requested", "dismiss.completed"]
ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def serialize(value):
    return (json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + "\n").encode()


def reference(ref, base):
    require(isinstance(ref, dict) and isinstance(ref.get("path", ref.get("source_path")), str), "artifact path required")
    require(isinstance(ref.get("sha256"), str) and re.fullmatch("[a-f0-9]{64}", ref["sha256"]), "explicit SHA256 required")
    path = (base / ref.get("path", ref.get("source_path"))).resolve()
    return path


def read_ref(ref, base):
    path = reference(ref, base)
    require(path.is_file(), f"missing artifact: {path}")
    require(sha(path) == ref["sha256"], f"artifact hash mismatch: {path}")
    return json.loads(path.read_text()), path


def relocate(ref, old_base, new_base):
    path = reference(ref, old_base)
    return {"path": os.path.relpath(path, new_base), "sha256": ref["sha256"]}


def write_immutable(path, value):
    content = serialize(value)
    if path.exists():
        require(path.read_bytes() == content, f"frozen file cannot be replaced: {path}")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive creation prevents a concurrent freeze from overwriting evidence.
        with path.open("xb") as stream:
            stream.write(content)
    return {"path": path.name, "sha256": sha(path)}


def freeze(plan_path, output):
    plan_path, output = Path(plan_path).resolve(), Path(output).resolve()
    plan = json.loads(plan_path.read_text())
    require(plan.get("schema_version") == 1 and isinstance(plan.get("batch_id"), str) and plan["batch_id"], "versioned batch ID required")
    matrix, _ = read_ref(plan["matrix"], plan_path.parent)
    expected = cells(matrix)
    read_ref(plan["profile"], plan_path.parent)
    assignments = {split: [] for split in SPLITS}
    occupied = set()
    for assignment in plan.get("assignments", []):
        split, cell_id = assignment["split"], assignment["cell_id"]
        require(split in SPLITS and cell_id in expected, "unknown split/cell assignment")
        require((split, cell_id) not in occupied, "one immutable cohort pair per split/cell revision required")
        occupied.add((split, cell_id))
        role = expected[cell_id]["role"]
        require(split == "diagnostic" or role == ("holdout" if split == "holdout" else "training"), "holdout/training cell role mismatch")
        trials = assignment.get("expected_trials", list(range(1, matrix.get("minimum_trials", 10) + 1)))
        require(isinstance(trials, list) and trials and all(type(t) is int and t > 0 for t in trials) and len(set(trials)) == len(trials), "unique positive expected trial IDs required")
        read_ref(assignment["recipe"], plan_path.parent)
        entry = {**assignment, "expected_trials": sorted(trials)}
        for key in ("native", "candidate", "recipe"):
            entry[key] = relocate(assignment[key], plan_path.parent, output)
        assignments[split].append(entry)
    index = {"schema_version": 1, "batch_id": plan["batch_id"], "plan_sha256": sha(plan_path),
             "matrix": relocate(plan["matrix"], plan_path.parent, output),
             "profile": relocate(plan["profile"], plan_path.parent, output), "splits": []}
    for split in SPLITS:
        payload = {"schema_version": 1, "batch_id": plan["batch_id"], "split": split,
                   "assignments": sorted(assignments[split], key=lambda x: x["cell_id"])}
        index["splits"].append({"split": split, **write_immutable(output / (split + ".json"), payload)})
    index_ref = write_immutable(output / "index.json", index)
    return {"status": "frozen", "index_path": str(output / "index.json"), "index_sha256": index_ref["sha256"],
            "assignments": {split: len(values) for split, values in assignments.items()}}


def identity(header):
    return {key: header[key] for key in ("scenario_id", "os", "device", "environment")} | {
        "configuration": {key: value for key, value in header["configuration"].items() if key != "trial"}}


def validate_v2(rows, role, artifact):
    header, frames, events = validate(rows, role)
    require(header.get("native_contract_version") == 2 and header["evidence_kind"] == "runtime", "fresh canonical v2 runtime evidence required")
    require(set(header["configuration"]) == CONFIG_KEYS, "canonical v2 requires exactly 13 effective configuration keys")
    require(type(header["configuration"]["trial"]) is int and header["configuration"]["trial"] > 0, "positive observed trial ID required")
    require(header["run_id"] == artifact["run_id"] and header["configuration"]["trial"] == artifact["trial"], "manifest run/trial identity does not match hashed header")
    require(all(row["seq"] == i for i, row in enumerate(rows)), "partial/lost record sequence")
    require(not any(event["name"] == "run.error" for event in events), "run.error explicitly invalidates evidence")
    for row in frames:
        for section in ("metrics", "state"):
            for key, value in row[section].items():
                if value is None:
                    require(isinstance(row.get("unavailable", {}).get(key), str) and row["unavailable"][key].strip(), "null observation lacks applicability/unavailable reason")
        for key in ("selected_detent", "target_detent"):
            require(row["state"].get(key) not in ("com.apple.UIKit.medium", "com.apple.UIKit.large"), "noncanonical system detent ID")
    terminal = [i for i, row in enumerate(rows) if row.get("terminal") is True]
    require(len(terminal) == 1, "missing or duplicate successful terminal marker")
    last = rows[terminal[0]]
    require(last.get("name") == "dismiss.completed", "unapproved terminal outcome")
    require(all(row.get("name") == "batch.completed" and row["type"] == "event" for row in rows[terminal[0] + 1:]), "observations after terminal outcome")
    if header["scenario_id"] == "native.medium_large.programmatic" or header["scenario_id"].startswith("synthetic."):
        core = [event for event in events if event["name"] not in ("detent.resolved", "batch.completed")]
        require([event["name"] for event in core] == PROGRAMMATIC_EVENTS, "incomplete canonical programmatic event sequence")
        require([event["data"].get("target") for event in core if event["name"] == "detent.requested"] == ["large", "medium"], "wrong canonical request targets")
    return header


def load_cohort(ref, base, role, split, audit):
    selected = {}
    all_records = []
    try:
        manifest, path = read_ref(ref, base)
        require(manifest.get("schema_version") == 1 and manifest.get("implementation") == role, "cohort role/version mismatch")
        require(manifest.get("split") == split, "cohort split mismatch")
        artifacts = manifest.get("artifacts")
        require(isinstance(artifacts, list), "cohort artifact roster required")
        seen = set()
        candidates = []
        for artifact in sorted(artifacts, key=lambda x: (x.get("trial", 0), x.get("attempt", 0), x.get("run_id", ""))):
            item = {"cohort_id": manifest.get("cohort_id"), "split": split, "implementation": role,
                    **{key: artifact.get(key) for key in ("trial", "attempt", "run_id", "sha256")}, "status": "rejected"}
            audit.append(item)
            try:
                require(type(artifact.get("trial")) is int and artifact["trial"] > 0 and type(artifact.get("attempt")) is int and artifact["attempt"] > 0, "positive trial/attempt required")
                slot = (artifact["trial"], artifact["attempt"])
                require(slot not in seen, "duplicate trial/attempt in cohort")
                seen.add(slot)
                source = reference(artifact, path.parent)
                require(source.is_file() and sha(source) == artifact["sha256"], "source artifact missing/hash mismatch")
                rows = read_jsonl(source)
                header = validate_v2(rows, role, artifact)
                require(artifact.get("status") == "complete", "producer did not declare complete evidence")
                record = {"artifact": {**artifact, "path": str(source)}, "header": header, "rows": rows, "audit": item}
                candidates.append(record)
                all_records.append(record)
                item["status"] = "complete"
            except (TraceError, OSError, ValueError, KeyError, TypeError) as error:
                item["reason"] = str(error)
                if "run.error" in str(error):
                    item["status"] = "failed"
                elif artifact.get("status") == "unsupported":
                    item["status"] = "unsupported"
                elif artifact.get("status") == "partial" or "terminal" in str(error) or "sequence" in str(error):
                    item["status"] = "partial"
        if candidates:
            require(all(schema_equal(identity(record["header"]), identity(candidates[0]["header"])) for record in candidates), "mixed cohort metadata/configuration")
        for record in candidates:
            trial = record["artifact"]["trial"]
            if trial not in selected:
                selected[trial] = record
            else:
                record["audit"]["selection"] = "later complete attempt retained; never score-selected"
        for record in selected.values():
            record["audit"]["selection"] = "first structurally complete attempt"
    except (TraceError, OSError, ValueError, KeyError, TypeError) as error:
        audit.append({"split": split, "implementation": role, "status": "rejected", "reason": str(error), "manifest": ref})
        selected = {}
    return selected, all_records


def outcome(report):
    if report.get("verdict") == "PASS" and report.get("native_parity_eligible"):
        return "PASS"
    observed_fail = any(not value.get("pass", False) for value in report.get("metrics", {}).values())
    observed_fail |= any(not value.get("pass", False) for value in report.get("event_timing", {}).values())
    observed_fail |= any(value.get("observed") and not value.get("match") for value in report.get("states", {}).values())
    observed_fail |= any(issue.startswith(("incompatible", "event data/outcome", "event sequence", "event order")) for issue in report.get("issues", []))
    return "FAIL" if observed_fail else "UNRESOLVED"


def run(index_path, split_filter=None):
    result = {"schema_version": 1, "verdict": "FAIL", "parity_proven": False, "proof_scope": "strict_runtime_batch",
              "issues": [], "artifact_audit": [], "pairs": [], "phases": [], "coverage": {},
              "pair_counts": {"paired": 0, "unresolved": 0}, "phase_counts": {"PASS": 0, "FAIL": 0, "UNRESOLVED": 0},
              "coverage_counts": {"PASS": 0, "FAIL": 0, "UNRESOLVED": 0}}
    try:
        index_path = Path(index_path).resolve()
        index = json.loads(index_path.read_text())
        require(index.get("schema_version") == 1 and {ref["split"] for ref in index["splits"]} == set(SPLITS), "all frozen split files required")
        matrix, _ = read_ref(index["matrix"], index_path.parent)
        expected = cells(matrix)
        result["required_cells"] = len(expected)
        result["required_checks"] = sum(len(cell["check_contracts"]) for cell in expected.values())
        result["coverage"] = {cell_id: {"status": "UNRESOLVED", "complete_trials": [], "required_trials": matrix.get("minimum_trials", 10)} for cell_id in expected}
        result["coverage_counts"]["UNRESOLVED"] = len(expected)
        profile, _ = read_ref(index["profile"], index_path.parent)
        result["batch_id"] = index["batch_id"]
        result["frozen_index_sha256"] = sha(index_path)
        result["analyzer_sha256"] = sha(ROOT / "analysis/compare.py")
        result["matrix_sha256"] = index["matrix"]["sha256"]
        rosters = []
        registry = {}
        for split_ref in index["splits"]:
            payload, _ = read_ref(split_ref, index_path.parent)
            split = split_ref["split"]
            require(payload["split"] == split and payload["batch_id"] == index["batch_id"], "frozen split identity mismatch")
            for assignment in payload["assignments"]:
                native, nr = load_cohort(assignment["native"], index_path.parent, "native", split, result["artifact_audit"])
                candidate, cr = load_cohort(assignment["candidate"], index_path.parent, "flutter", split, result["artifact_audit"])
                for item in result["artifact_audit"]:
                    if item.get("reason") == "cohort split mismatch" and "cohort split mismatch" not in result["issues"]:
                        result["issues"].append("cohort split mismatch")
                for record in nr + cr:
                    for identity_key in ((record["header"]["implementation"], "run", record["header"]["run_id"]), ("hash", record["artifact"]["sha256"])):
                        require(identity_key not in registry or registry[identity_key] == (split, assignment["cell_id"], record["artifact"]["trial"]), "artifact/run reuse crosses split or independent trial boundary")
                        registry[identity_key] = (split, assignment["cell_id"], record["artifact"]["trial"])
                rosters.append((split, assignment, native, candidate))
        coverage = {cell_id: {check_id: set() for check_id in cell["check_contracts"]} for cell_id, cell in expected.items()}
        failures = set()
        for split, assignment, native, candidate in rosters:
            if split_filter and split != split_filter:
                continue
            cell_id = assignment["cell_id"]
            require(cell_id in expected, "unknown frozen cell")
            cell = expected[cell_id]
            recipe, _ = read_ref(assignment["recipe"], index_path.parent)
            for trial in assignment["expected_trials"]:
                n, c = native.get(trial), candidate.get(trial)
                if n is None or c is None:
                    result["pair_counts"]["unresolved"] += 1
                    continue
                if not schema_equal(identity(n["header"]), identity(c["header"])):
                    result["pair_counts"]["unresolved"] += 1
                    result["issues"].append(f"{cell_id}/trial{trial}: incompatible canonical metadata/configuration")
                    continue
                require(n["header"]["scenario_id"] == cell["scenario_id"], "source scenario does not match frozen case")
                require(int(n["header"]["os"]["version"].split(".")[0]) == cell["ios_major"] and n["header"]["environment"]["orientation"] == cell["orientation"], "source environment does not match frozen cell")
                pair = {"cell_id": cell_id, "split": split, "trial": trial,
                        "native": {key: n["artifact"][key] for key in ("run_id", "trial", "attempt", "path", "sha256")},
                        "candidate": {key: c["artifact"][key] for key in ("run_id", "trial", "attempt", "path", "sha256")}}
                result["pairs"].append(pair)
                result["pair_counts"]["paired"] += 1
                for check_id, contract in cell["check_contracts"].items():
                    cfg = {**profile, "window": contract["window"], "alignment": {"event": contract["window"]["start_event"], "occurrence": contract["window"]["start_occurrence"]}}
                    # Approved exclusions are explicit; all other analyzer gates remain intact.
                    cfg["auxiliary_events"] = ["detent.resolved", "batch.completed"]
                    report = compare({"native": n["rows"], "candidate": c["rows"], "config": cfg})
                    status = outcome(report)
                    reasons = []
                    if assignment.get("runtime_input_verified") is not True:
                        reasons.append("actual input delivery verification absent")
                    if recipe.get("scenario_id") != cell["scenario_id"] or recipe.get("role") != cell["role"]:
                        reasons.append("frozen recipe scenario/role mismatch")
                    for header in (n["header"], c["header"]):
                        params = header["configuration"].get("measurement_parameters", {})
                        if not all(key in params and schema_equal(params[key], value) for key, value in contract["parameters"].items()):
                            reasons.append("required subcondition unobserved in canonical configuration")
                    params = recipe.get("preconditions", {}).get("measurement_parameters", {})
                    if not all(key in params and schema_equal(params[key], value) for key, value in contract["parameters"].items()):
                        reasons.append("frozen recipe does not pin subcondition")
                    if status == "PASS" and reasons:
                        status = "UNRESOLVED"
                    phase = {"cell_id": cell_id, "trial": trial, "split": split, "check_id": check_id,
                             "status": status, "reasons": reasons, "analyzer": report}
                    result["phases"].append(phase)
                    result["phase_counts"][status] += 1
                    if split != "diagnostic":
                        if status == "PASS":
                            coverage[cell_id][check_id].add(trial)
                        elif status == "FAIL":
                            failures.add(cell_id)
        minimum = matrix.get("minimum_trials", 10)
        result["coverage_counts"] = {"PASS": 0, "FAIL": 0, "UNRESOLVED": 0}
        for cell_id, checks in coverage.items():
            complete = set.intersection(*checks.values())
            status = "PASS" if len(complete) >= minimum else "FAIL" if cell_id in failures else "UNRESOLVED"
            result["coverage"][cell_id] = {"status": status, "complete_trials": sorted(complete), "required_trials": minimum,
                "checks": {key: {"passing_trials": sorted(value)} for key, value in checks.items()}}
            result["coverage_counts"][status] += 1
        result["required_cells"] = len(expected)
        result["required_checks"] = sum(len(cell["check_contracts"]) for cell in expected.values())
        result["verdict"] = "PASS" if not result["issues"] and result["coverage_counts"]["FAIL"] == result["coverage_counts"]["UNRESOLVED"] == 0 else "FAIL"
        result["limitations"] = ["diagnostic pairs never count toward acceptance", "analyzer FAIL is preserved; unavailable evidence remains unresolved", "canonical v2 parameterized checks need an approved applicability/parameter contract", "actual displayed frames and native shape calibration remain independent"]
    except (TraceError, OSError, ValueError, KeyError, TypeError, IndexError) as error:
        result["issues"].append(str(error))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    f = sub.add_parser("freeze")
    f.add_argument("plan")
    f.add_argument("--output-directory", required=True)
    r = sub.add_parser("run")
    r.add_argument("index")
    r.add_argument("--split", choices=SPLITS)
    r.add_argument("--output")
    args = parser.parse_args()
    try:
        result = freeze(args.plan, args.output_directory) if args.command == "freeze" else run(args.index, args.split)
    except (TraceError, OSError, ValueError, KeyError, TypeError) as error:
        result = {"verdict": "FAIL", "issues": [str(error)], "parity_proven": False}
    if args.command == "run" and args.output:
        path = Path(args.output)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(serialize(result))
    print(json.dumps(result, indent=2, allow_nan=False))
    return 0 if result.get("status") == "frozen" or result.get("verdict") == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
