#!/usr/bin/env python3
"""Manifest-hashed canonical v2 pairing; never edits traces or analyzer gates."""
import argparse
import copy
from collections import Counter
import hashlib
import gzip
import json
import os
from pathlib import Path
import re
import sys
import importlib.util

from compare import TraceError, compare, read_jsonl, require, schema_equal, validate, validate_schema, indexed_events
from regression import cells, normalize_window

SPLITS = ("diagnostic", "training", "holdout")
CONFIG_KEYS = {"trial", "detents", "surface", "grabber", "page_sizing", "modal_in_presentation", "largest_undimmed",
               "presentation_style", "preferred_content_size", "placement", "edge_attached_in_compact_height",
               "width_follows_preferred_content_size", "scroll_expansion"}
PROGRAMMATIC_EVENTS = ["present.requested", "present.first_visible", "present.completed", "detent.requested", "detent.requested",
                       "dismiss.requested", "dismiss.completed"]
ROOT = Path(__file__).resolve().parents[1]
CONDITION_IDENTITY = ("recipe_id", "recipe_revision", "parameters", "input_source", "accessibility")
V2_ONLY_MARKERS = frozenset({"scenario_map", "scenario_revision", "conditions"})
OBSERVABLE_FIELDS = {
    "target_detent": ("state.target_detent",),
    "scroll": ("state.scroll_owner", "metrics.scroll.offset"),
    "hit_testing": ("state.underlying_hit_test",),
    "keyboard": ("observations.keyboard",), "stack_layers": ("observations.stack_layers",),
    "contour": ("observations.contour",), "performance": ("observations.performance",),
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def reject_legacy_v2_markers(value, context):
    require(isinstance(value, dict), f"{context}: object required")
    markers = sorted(V2_ONLY_MARKERS.intersection(value))
    require(not markers, f"{context}: v2-only markers {markers} require an explicit v2 plan/index")


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


def read_contract_ref(ref, base, legacy):
    """Only exact historical contract path/hash pairs may use the immutable snapshot."""
    path = reference(ref, base)
    pins = {
        ROOT / "spec/test_matrix.json": ("test_matrix.json", "6d12d9b534451dc13b184a4f1ffd3e24821aabfc9887b90dce872ff64d93a933"),
        ROOT / "measurement/profiles/full.json": ("full.json", "ebcd96dc8ff8e90aaeb52267062d2b8baa6a785498acb312a55a3663f275259d"),
    }
    if legacy and path in pins and ref["sha256"] == pins[path][1]:
        name, digest = pins[path]
        return read_ref({"path": str(ROOT / "measurement/runtime/contracts/v1" / name), "sha256": digest}, base)
    return read_ref(ref, base)


def load_scenario_map(ref, base):
    mapping, _ = read_ref(ref, base)
    schema = json.loads((ROOT / "measurement/schema/scenario.schema.json").read_text())
    validate_schema(mapping, schema)
    require(isinstance(mapping["entries"], list) and mapping["entries"], "nonempty explicit scenario map required")
    seen = set()
    for entry in mapping["entries"]:
        validate_schema(entry, schema["properties"]["entries"]["items"], root=schema)
        for role in ("matrix", "native", "flutter"):
            if entry[role] is not None:
                key = (role, entry[role], entry["revision"])
                require(key not in seen, "scenario map must have unique matrix/source aliases per revision")
                seen.add(key)
    return mapping


def resolve_scenario(mapping, scenario, revision):
    require(type(revision) is int and revision > 0, "explicit positive scenario revision required")
    matches = [entry for entry in mapping["entries"] if entry["matrix"] == scenario and entry["revision"] == revision]
    require(len(matches) == 1, "scenario/revision must resolve through one unique explicit scenario map entry")
    return matches[0]


def validate_conditions(conditions):
    schema = json.loads((ROOT / "measurement/schema/trace-v2.schema.json").read_text())
    validate_schema(conditions, schema["$defs"]["conditions"], root=schema)
    require(bool(conditions["applicability"]), "nonempty phase applicability declarations required")
    return {key: conditions[key] for key in CONDITION_IDENTITY}


def validate_recipe(recipe, cell, revision):
    require(recipe.get("scenario_id") == cell["scenario_id"] and recipe.get("role") == cell["role"], "frozen recipe scenario/role mismatch")
    require(type(recipe.get("scenario_revision")) is int and recipe["scenario_revision"] == revision, "frozen recipe scenario revision mismatch")
    declared = validate_conditions(recipe.get("conditions"))
    require(declared["recipe_id"] == recipe.get("id"), "condition recipe_id must identify the actual frozen recipe")
    return declared


def phase_policy(profile, contract):
    identifier = contract.get("applicability_policy_id")
    policies = profile.get("applicability_policies", {})
    require(isinstance(identifier, str) and identifier in policies, "explicit known applicability policy ID required")
    policy = policies[identifier]
    require(isinstance(policy, dict) and set(policy) == {"phase", "observables"}, "malformed phase policy")
    require(policy["phase"] == contract.get("phase"), "matrix phase does not match profile policy")
    rules = policy["observables"]
    require(isinstance(rules, dict) and set(rules) == set(OBSERVABLE_FIELDS), "phase policy must govern all seven observables")
    require(all(value in ("required", "not_applicable", "unavailable") for value in rules.values()), "unknown applicability status")
    require(rules["target_detent"] != "not_applicable" or policy["phase"] == "dismiss", "target detent exemption requires explicit dismissal phase policy")
    if policy["phase"] == "dismiss":
        require(contract["window"]["start_event"] == "dismiss.requested" and
                contract["window"]["end_event"] == "dismiss.completed", "dismissal policy requires observed dismissal boundaries")
    require("applicability" not in contract or schema_equal(contract["applicability"], rules), "matrix cannot relax the profile phase policy")
    return identifier, policy


def agree_phase_policy(profile, contract, headers):
    identifier, policy = phase_policy(profile, contract)
    for header in headers:
        declaration = header.get("conditions", {}).get("applicability", {}).get(policy["phase"])
        require(schema_equal(declaration, policy["observables"]), "trace/recipe applicability must agree with the profile phase policy")
    return identifier, policy


def scope_phase(profile, contract, rows, policy_info):
    identifier, policy = policy_info
    cfg = {**profile, "states": list(profile.get("states", []))}
    audit = {"policy_id": identifier, "phase": policy["phase"], "approved_exemptions": [],
             "unresolved_observables": [], "missing_observables": [], "reason_failures": []}
    for group, status in policy["observables"].items():
        fields = OBSERVABLE_FIELDS[group]
        if status == "not_applicable":
            for field in fields:
                section, key = field.split(".", 1)
                if section == "state" and key in cfg["states"]:
                    cfg["states"].remove(key)
                elif section == "metrics":
                    cfg.get("metrics", {}).pop(key, None)
                audit["approved_exemptions"].append(field)
            continue
        unresolved = status == "unavailable"
        for records in rows:
            events = indexed_events([row for row in records if row["type"] == "event"])
            start = f"{contract['window']['start_event']}#{contract['window']['start_occurrence']}"
            end = f"{contract['window']['end_event']}#{contract['window']['end_occurrence']}"
            require(start in events and end in events, "missing applicability phase boundary")
            frames = [row for row in records if row["type"] == "frame" and events[start]["t_ns"] <= row["t_ns"] < events[end]["t_ns"]]
            if not frames:
                unresolved = True
            for frame in frames:
                for field in fields:
                    section, key = field.split(".", 1)
                    value = frame.get(section, {}).get(key)
                    if status == "required" and (value is None or value == {} or value == [] or value == ""):
                        unresolved = True
                        audit["missing_observables"].append(field)
                    if status == "unavailable":
                        reason = frame.get("unavailable", {}).get(field, frame.get("unavailable", {}).get(key))
                        if not isinstance(reason, str) or not reason.strip():
                            audit["reason_failures"].append("missing_reason")
        # This slice has no reviewed structured comparators. Presence is not
        # native contour/keyboard/stack/performance parity; do not manufacture PASS.
        if group in ("keyboard", "stack_layers", "contour", "performance") and status == "required":
            unresolved = True
            audit.setdefault("unsupported_comparisons", []).append(group)
        if unresolved:
            audit["unresolved_observables"].append(group)
    for key in ("approved_exemptions", "unresolved_observables", "missing_observables", "reason_failures"):
        audit[key] = sorted(set(audit[key]))
    return cfg, audit


def mapped_pair(n, c, entry, recipe_conditions):
    for record, role in ((n, "native"), (c, "flutter")):
        header = record["header"]
        require(entry[role] is not None and header["scenario_id"] == entry[role], "source scenario is not registered for this matrix/revision")
        require(type(header.get("scenario_revision")) is int and header["scenario_revision"] == entry["revision"], "source scenario revision mismatch")
        observed = validate_conditions(header.get("conditions"))
        require(schema_equal(observed, recipe_conditions), "trace conditions incompatible with frozen recipe")
        require(schema_equal(header["environment"].get("system_settings"), observed["accessibility"]), "conditions accessibility does not match observed environment")
    # This projection changes only identity used by comparison, never source bytes,
    # timestamps, observations or semantic configuration. Pair reports retain aliases.
    views = []
    for record in (n, c):
        views.append([{**record["rows"][0], "scenario_id": entry["matrix"]}, *record["rows"][1:]])
    for view, record, role in zip(views, (n, c), ("native", "flutter")):
        validate_v2(view, role, record["artifact"])
    require(schema_equal(identity(views[0][0]), identity(views[1][0])), "incompatible canonical metadata/configuration/conditions")
    return views


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
    require(type(plan.get("schema_version")) is int and plan["schema_version"] in (1, 2) and isinstance(plan.get("batch_id"), str) and plan["batch_id"], "versioned batch ID required")
    legacy = plan["schema_version"] == 1
    if legacy:
        reject_legacy_v2_markers(plan, "legacy plan")
    require(legacy or "scenario_map" in plan, "v2 plan requires an explicit scenario map reference")
    mapping = None if legacy else load_scenario_map(plan["scenario_map"], plan_path.parent)
    matrix, _ = read_contract_ref(plan["matrix"], plan_path.parent, legacy)
    expected = cells(matrix)
    profile, _ = read_contract_ref(plan["profile"], plan_path.parent, legacy)
    assignments = {split: [] for split in SPLITS}
    occupied = set()
    for assignment in plan.get("assignments", []):
        if legacy:
            reject_legacy_v2_markers(assignment, "legacy assignment")
        split, cell_id = assignment["split"], assignment["cell_id"]
        require(split in SPLITS and cell_id in expected, "unknown split/cell assignment")
        require((split, cell_id) not in occupied, "one immutable cohort pair per split/cell revision required")
        occupied.add((split, cell_id))
        role = expected[cell_id]["role"]
        require(split == "diagnostic" or role == ("holdout" if split == "holdout" else "training"), "holdout/training cell role mismatch")
        trials = assignment.get("expected_trials", list(range(1, matrix.get("minimum_trials", 10) + 1)))
        require(isinstance(trials, list) and trials and all(type(t) is int and t > 0 for t in trials) and len(set(trials)) == len(trials), "unique positive expected trial IDs required")
        recipe, _ = read_ref(assignment["recipe"], plan_path.parent)
        if legacy:
            reject_legacy_v2_markers(recipe, "legacy recipe")
        else:
            resolved = resolve_scenario(mapping, expected[cell_id]["scenario_id"], assignment.get("scenario_revision"))
            validate_recipe(recipe, expected[cell_id], resolved["revision"])
            for contract in expected[cell_id]["check_contracts"].values():
                agree_phase_policy(profile, contract, [recipe])
        entry = {**assignment, "expected_trials": sorted(trials)}
        for key in ("native", "candidate", "recipe"):
            entry[key] = relocate(assignment[key], plan_path.parent, output)
        assignments[split].append(entry)
    index = {"schema_version": plan["schema_version"], "batch_id": plan["batch_id"], "plan_sha256": sha(plan_path),
             "matrix": relocate(plan["matrix"], plan_path.parent, output),
             "profile": relocate(plan["profile"], plan_path.parent, output), "splits": []}
    if not legacy:
        index["scenario_map"] = relocate(plan["scenario_map"], plan_path.parent, output)
    if any(cell["role"] == "holdout" for cell in expected.values()) or "holdout_definitions" in plan:
        require("holdout_definitions" in plan, "holdout definitions must be frozen before new batch assignment")
        read_ref(plan["holdout_definitions"], plan_path.parent)
        index["holdout_definitions"] = relocate(plan["holdout_definitions"], plan_path.parent, output)
    for split in SPLITS:
        payload = {"schema_version": 1, "batch_id": plan["batch_id"], "split": split,
                   "assignments": sorted(assignments[split], key=lambda x: x["cell_id"])}
        index["splits"].append({"split": split, **write_immutable(output / (split + ".json"), payload)})
    index_ref = write_immutable(output / "index.json", index)
    return {"status": "frozen", "index_path": str(output / "index.json"), "index_sha256": index_ref["sha256"],
            "assignments": {split: len(values) for split, values in assignments.items()}}


def identity(header):
    result = {key: header[key] for key in ("scenario_id", "os", "device", "environment")} | {
        "configuration": {key: value for key, value in header["configuration"].items() if key != "trial"}}
    for key in ("conditions", "scenario_revision"):
        if key in header:
            result[key] = header[key]
    return result


def import_cohort(source_manifest, source_root, adapter, role, split, cohort_id, output, artifact_directory, attempt=1):
    """Explicit producer adapters preserve bytes and producer outcomes; no trace adaptation."""
    source_manifest, source_root = Path(source_manifest).resolve(), Path(source_root).resolve()
    output, artifact_directory = Path(output).resolve(), Path(artifact_directory).resolve()
    producer = json.loads(source_manifest.read_text())
    require(producer.get("schema_version") == 1, "unsupported producer manifest")
    require(adapter != "flutter-timing-v1" or role == "flutter", "producer adapter/role mismatch")
    require(adapter == "flutter-timing-v1" or role == "native", "producer adapter/role mismatch")
    pilot = adapter == "native-interaction-pilot-v1"
    if pilot:
        require(split == "diagnostic" and producer.get("status") == "diagnostic", "interaction pilot cannot be promoted beyond diagnostic scope")
    roster = producer.get("entries") if adapter in ("native-timing-v1", "native-interaction-pilot-v1") else producer.get("artifacts")
    require(isinstance(roster, list) and roster, "producer manifest artifact roster required")
    artifact_directory.mkdir(parents=True, exist_ok=True)
    producer_copy = artifact_directory / (sha(source_manifest) + ".producer.json")
    if producer_copy.exists():
        require(producer_copy.read_bytes() == source_manifest.read_bytes(), "producer manifest content collision")
    else:
        with producer_copy.open("xb") as stream:
            stream.write(source_manifest.read_bytes())
    result = {"schema_version": 1, "cohort_id": cohort_id, "implementation": role, "split": split,
              "producer_adapter": adapter, "producer_manifest": {"path": os.path.relpath(producer_copy, output.parent), "sha256": sha(source_manifest), "source_path": str(source_manifest)},
              "producer_provenance": {key: value for key, value in producer.items() if key not in ("entries", "artifacts", "runtime")}, "artifacts": []}
    for entry in roster:
        producer_split = entry.get("split", entry.get("role", producer.get("split")))
        require(producer_split == split or pilot and producer_split == "training", "producer split cannot be reassigned")
        path = reference(entry, source_root)
        require(path.is_relative_to(source_root), "producer path escapes explicit source root")
        require(path.is_file() and sha(path) == entry["sha256"], "producer source hash mismatch")
        content = path.read_bytes()
        raw = gzip.decompress(content) if str(path).endswith(".gz") else content
        if entry.get("raw_sha256") is not None:
            require(hashlib.sha256(raw).hexdigest() == entry["raw_sha256"], "producer raw hash mismatch")
        observations = [json.loads(line) for line in raw.decode().splitlines() if line.strip()]
        ordinal = entry.get("attempt", producer.get("attempt", attempt))
        require(type(ordinal) is int and ordinal > 0, "explicit positive producer attempt ordinal required")
        item = {"run_id": entry["run_id"], "trial": entry["trial"], "attempt": ordinal,
                "sha256": entry["sha256"], "raw_sha256": hashlib.sha256(raw).hexdigest(),
                "source_path": str(path), "source_attempt_id": entry.get("attempt_id"), "status": "partial"}
        validate_v2(observations, role, item)
        if adapter == "flutter-timing-v1":
            require(producer.get("complete") is True and entry.get("terminal") == "dismiss.completed", "producer did not declare complete candidate capture")
        elif adapter == "native-timing-v1":
            require(producer.get("status") == "complete_resting_and_replay_timing_only" and entry.get("terminal") is True, "producer did not declare complete timing capture")
        item["status"] = "complete"
        if pilot:
            item["status"] = "unsupported"
            item["quality_error"] = "pilot/uncommitted source is diagnostic only; no paired candidate or accepted timing claim"
            item["producer_outcomes"] = entry.get("outcomes", [])
        if role == "native" and not pilot:
            spec = importlib.util.spec_from_file_location("native_evidence_contract", ROOT / "native_reference/scripts/evidence_contract.py")
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            try:
                module.validate_run(observations)
            except ValueError as error:
                item["status"] = "partial"
                item["quality_error"] = str(error)
        artifact_directory.mkdir(parents=True, exist_ok=True)
        destination = artifact_directory / (entry["sha256"] + (".jsonl.gz" if str(path).endswith(".gz") else ".jsonl"))
        if destination.exists():
            require(destination.read_bytes() == content, "content-addressed artifact collision")
        else:
            with destination.open("xb") as stream:
                stream.write(content)
        item["path"] = os.path.relpath(destination, output.parent)
        result["artifacts"].append(item)
    write_immutable(output, result)
    return {"status": "imported", "manifest": str(output), "sha256": sha(output), "artifacts": len(result["artifacts"]),
            "outcomes": dict(Counter(item["status"] for item in result["artifacts"])), "producer_sha256": sha(source_manifest)}


def validate_v2(rows, role, artifact):
    header, frames, events = validate(rows, role)
    require(header.get("native_contract_version") == 2 and header["evidence_kind"] == "runtime", "fresh canonical v2 runtime evidence required")
    require(set(header["configuration"]) == CONFIG_KEYS, "canonical v2 requires exactly 13 effective configuration keys")
    if "conditions" in header:
        schema = json.loads((ROOT / "measurement/schema/trace-v2.schema.json").read_text())
        validate_schema(header, schema)
        validate_conditions(header["conditions"])
        detents = header["configuration"]["detents"]
        require(bool(detents) and all(isinstance(value, str) and value for value in detents), "nonempty semantic detent IDs required")
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
            except (TraceError, OSError, EOFError, ValueError, KeyError, TypeError) as error:
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
        require(type(index.get("schema_version")) is int and index["schema_version"] in (1, 2) and {ref["split"] for ref in index["splits"]} == set(SPLITS), "all frozen split files required")
        legacy = index["schema_version"] == 1
        if legacy:
            reject_legacy_v2_markers(index, "legacy index")
        require(legacy or "scenario_map" in index, "v2 index requires a scenario map reference")
        mapping = None if legacy else load_scenario_map(index["scenario_map"], index_path.parent)
        if not legacy:
            result["scenario_map_sha256"] = index["scenario_map"]["sha256"]
        matrix, _ = read_contract_ref(index["matrix"], index_path.parent, legacy)
        expected = cells(matrix)
        result["required_cells"] = len(expected)
        result["required_checks"] = sum(len(cell["check_contracts"]) for cell in expected.values())
        result["coverage"] = {cell_id: {"status": "UNRESOLVED", "complete_trials": [], "required_trials": matrix.get("minimum_trials", 10)} for cell_id in expected}
        result["coverage_counts"]["UNRESOLVED"] = len(expected)
        profile, _ = read_contract_ref(index["profile"], index_path.parent, legacy)
        if "holdout_definitions" in index:
            read_ref(index["holdout_definitions"], index_path.parent)
            result["holdout_definitions_sha256"] = index["holdout_definitions"]["sha256"]
        else:
            result["holdout_definition_status"] = "legacy diagnostic index; no holdout capture assigned or accepted"
        result["batch_id"] = index["batch_id"]
        result["frozen_index_sha256"] = sha(index_path)
        result["analyzer_sha256"] = sha(ROOT / "analysis/compare.py")
        result["runtime_orchestrator_sha256"] = sha(Path(__file__))
        result["matrix_sha256"] = index["matrix"]["sha256"]
        rosters = []
        registry = {}
        for split_ref in index["splits"]:
            payload, _ = read_ref(split_ref, index_path.parent)
            if legacy:
                reject_legacy_v2_markers(payload, "legacy split")
            split = split_ref["split"]
            require(payload["split"] == split and payload["batch_id"] == index["batch_id"], "frozen split identity mismatch")
            for assignment in payload["assignments"]:
                if legacy:
                    reject_legacy_v2_markers(assignment, "legacy assignment")
                    recipe, _ = read_ref(assignment["recipe"], index_path.parent)
                    reject_legacy_v2_markers(recipe, "legacy recipe")
                native, nr = load_cohort(assignment["native"], index_path.parent, "native", split, result["artifact_audit"])
                candidate, cr = load_cohort(assignment["candidate"], index_path.parent, "flutter", split, result["artifact_audit"])
                for item in result["artifact_audit"]:
                    if item.get("reason") == "cohort split mismatch" and "cohort split mismatch" not in result["issues"]:
                        result["issues"].append("cohort split mismatch")
                for record in nr + cr:
                    if legacy:
                        reject_legacy_v2_markers(record["header"], "legacy trace session")
                    for identity_key in ((record["header"]["implementation"], "run", record["header"]["run_id"]), ("hash", record["artifact"]["sha256"])):
                        require(identity_key not in registry or registry[identity_key] == (split, assignment["cell_id"], record["artifact"]["trial"]), "artifact/run reuse crosses split or independent trial boundary")
                        registry[identity_key] = (split, assignment["cell_id"], record["artifact"]["trial"])
                rosters.append((split, assignment, native, candidate))
        coverage = {cell_id: {check_id: set() for check_id in cell["check_contracts"]} for cell_id, cell in expected.items()}
        failures = set()
        geometry_bindings = {}
        for split, assignment, native, candidate in rosters:
            if split_filter and split != split_filter:
                continue
            cell_id = assignment["cell_id"]
            require(cell_id in expected, "unknown frozen cell")
            cell = expected[cell_id]
            recipe, _ = read_ref(assignment["recipe"], index_path.parent)
            entry = None if legacy else resolve_scenario(mapping, cell["scenario_id"], assignment.get("scenario_revision"))
            recipe_conditions = None if legacy else validate_recipe(recipe, cell, entry["revision"])
            for trial in assignment["expected_trials"]:
                n, c = native.get(trial), candidate.get(trial)
                if n is None or c is None:
                    result["pair_counts"]["unresolved"] += 1
                    continue
                views = (n["rows"], c["rows"])
                try:
                    if legacy:
                        require(schema_equal(identity(n["header"]), identity(c["header"])), "incompatible canonical metadata/configuration")
                        require(n["header"]["scenario_id"] == cell["scenario_id"], "source scenario does not match frozen case")
                    else:
                        views = mapped_pair(n, c, entry, recipe_conditions)
                        for contract in cell["check_contracts"].values():
                            agree_phase_policy(profile, contract, [recipe, n["header"], c["header"]])
                except TraceError as error:
                    result["pair_counts"]["unresolved"] += 1
                    result["issues"].append(f"{cell_id}/trial{trial}: {error}")
                    continue
                require(int(n["header"]["os"]["version"].split(".")[0]) == cell["ios_major"] and n["header"]["environment"]["orientation"] == cell["orientation"], "source environment does not match frozen cell")
                size = n["header"]["device"]["logical_size"]
                size_key = tuple(sorted((size["width"], size["height"])))
                geometry = cell["device_geometry"]
                if (geometry in geometry_bindings and geometry_bindings[geometry] != size_key or
                    any(name != geometry and value == size_key for name, value in geometry_bindings.items())):
                    result["pair_counts"]["unresolved"] += 1
                    result["issues"].append(f"{cell_id}/trial{trial}: geometry role changed or duplicates another role")
                    continue
                geometry_bindings[geometry] = size_key
                pair = {"cell_id": cell_id, "split": split, "trial": trial,
                        "native": {key: n["artifact"][key] for key in ("run_id", "trial", "attempt", "path", "sha256")},
                        "candidate": {key: c["artifact"][key] for key in ("run_id", "trial", "attempt", "path", "sha256")}}
                if not legacy:
                    pair["scenario_mapping"] = copy.deepcopy(entry)
                    pair["comparison_view"] = "scenario_id-only projection; original source bytes unchanged"
                result["pairs"].append(pair)
                result["pair_counts"]["paired"] += 1
                for check_id, contract in cell["check_contracts"].items():
                    applicability = None
                    scoped = profile
                    if not legacy:
                        scoped, applicability = scope_phase(profile, contract, views, phase_policy(profile, contract))
                    cfg = {**scoped, "window": contract["window"], "alignment": {"event": contract["window"]["start_event"], "occurrence": contract["window"]["start_occurrence"]}}
                    # Approved exclusions are explicit; all other analyzer gates remain intact.
                    cfg["auxiliary_events"] = ["detent.resolved", "batch.completed"]
                    report = compare({"native": views[0], "candidate": views[1], "config": cfg})
                    status = outcome(report)
                    if applicability is not None:
                        approved = set(applicability["approved_exemptions"])
                        missing = set(report.get("full_acceptance_missing", []))
                        ready = not applicability["unresolved_observables"] and not applicability["reason_failures"]
                        eligible = (ready and report.get("verdict") == "PASS" and
                            report.get("proof_scope") == "runtime_trace_pair_only" and missing <= approved)
                        applicability["phase_eligible"] = eligible
                        applicability["scope"] = "profile-approved phase applicability; analyzer report unchanged"
                        if eligible:
                            status = "PASS"
                        elif status != "FAIL":
                            status = "UNRESOLVED"
                    reasons = []
                    action_failed = False
                    for record in (n, c):
                        observed_events = indexed_events([row for row in record["rows"] if row["type"] == "event"])
                        for name, fields in contract.get("expected_events", {}).items():
                            if name not in observed_events or not all(key in observed_events[name]["data"] and schema_equal(observed_events[name]["data"][key], value) for key, value in fields.items()):
                                reasons.append("required action/outcome not observed for matrix check")
                                action_failed = True
                    if assignment.get("runtime_input_verified") is not True:
                        reasons.append("actual input delivery verification absent")
                    if recipe.get("scenario_id") != cell["scenario_id"] or recipe.get("role") != cell["role"]:
                        reasons.append("frozen recipe scenario/role mismatch")
                    for header in (n["header"], c["header"]):
                        params = header["configuration"].get("measurement_parameters", {}) if legacy else header["conditions"]["parameters"]
                        if not all(key in params and schema_equal(params[key], value) for key, value in contract["parameters"].items()):
                            reasons.append("required subcondition unobserved in canonical configuration")
                    params = recipe.get("preconditions", {}).get("measurement_parameters", {}) if legacy else recipe["conditions"]["parameters"]
                    if not all(key in params and schema_equal(params[key], value) for key, value in contract["parameters"].items()):
                        reasons.append("frozen recipe does not pin subcondition")
                    if status == "PASS" and reasons:
                        status = "UNRESOLVED"
                    if action_failed:
                        status = "FAIL"
                    phase = {"cell_id": cell_id, "trial": trial, "split": split, "check_id": check_id,
                             "status": status, "reasons": reasons, "analyzer": report}
                    if applicability is not None:
                        phase["applicability"] = applicability
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
        result["geometry_bindings"] = {key: list(value) for key, value in geometry_bindings.items()}
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
    i = sub.add_parser("import-cohort")
    i.add_argument("manifest")
    i.add_argument("--adapter", choices=("flutter-timing-v1", "native-timing-v1", "native-reference-v1", "native-interaction-pilot-v1"), required=True)
    i.add_argument("--source-root", required=True)
    i.add_argument("--implementation", choices=("native", "flutter"), required=True)
    i.add_argument("--split", choices=SPLITS, required=True)
    i.add_argument("--cohort-id", required=True)
    i.add_argument("--attempt", type=int, default=1)
    i.add_argument("--output", required=True)
    i.add_argument("--artifact-directory", required=True)
    args = parser.parse_args()
    try:
        if args.command == "freeze":
            result = freeze(args.plan, args.output_directory)
        elif args.command == "import-cohort":
            result = import_cohort(args.manifest, args.source_root, args.adapter, args.implementation, args.split,
                                   args.cohort_id, args.output, args.artifact_directory, args.attempt)
        else:
            result = run(args.index, args.split)
    except (TraceError, OSError, EOFError, ValueError, KeyError, TypeError) as error:
        result = {"verdict": "FAIL", "issues": [str(error)], "parity_proven": False}
    if args.command == "run" and args.output:
        path = Path(args.output)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(serialize(result))
    display = result
    if args.command == "run" and args.output:
        display = {key: result.get(key) for key in ("verdict", "batch_id", "required_cells", "required_checks", "pair_counts", "phase_counts", "coverage_counts", "issues")}
        display["output"] = args.output
    print(json.dumps(display, indent=2, allow_nan=False))
    return 0 if result.get("status") in ("frozen", "imported") or result.get("verdict") == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
