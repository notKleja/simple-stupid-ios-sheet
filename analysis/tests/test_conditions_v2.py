"""Synthetic runtime-gate simulations, not native measurements or passing parity pairs."""
import copy
import gzip
import hashlib
import json
from pathlib import Path
import unittest

import test_runtime_batch as fixtures


def conditions():
    return {"recipe_id": "SYNTHETIC", "recipe_revision": 7, "parameters": {"scroll_offset_pt": 1},
        "input_source": "synthetic-delivered-input",
        "accessibility": {"reduce_motion": False, "voice_over": False, "content_size_category": "normal"},
        "applicability": {"present": {"target_detent": "required", "scroll": "not_applicable",
            "hit_testing": "not_applicable", "keyboard": "not_applicable", "stack_layers": "not_applicable",
            "contour": "not_applicable", "performance": "not_applicable"}}}


class ConditionsBatchTests(unittest.TestCase):
    tearDown = fixtures.RuntimeBatchTests.tearDown
    save = fixtures.RuntimeBatchTests.save
    invoke = fixtures.RuntimeBatchTests.invoke

    def setUp(self):
        fixtures.RuntimeBatchTests.setUp(self)
        self.recipe.update(scenario_revision=2, conditions=conditions())
        self.mapping = {"schema_version": 2, "entries": [{"matrix": "synthetic.runtime",
            "native": "native.synthetic.runtime", "flutter": "flutter.synthetic.runtime", "revision": 2}]}
        self.assignment_revision = 2

    def cohort(self, role, change=None):
        records = fixtures.rows(role)
        records[0].update(scenario_id=role + ".synthetic.runtime", scenario_revision=2, conditions=conditions())
        records[0]["environment"]["system_settings"] = copy.deepcopy(conditions()["accessibility"])
        if change:
            change(records)
        path = self.base / (role + ".jsonl.gz")
        path.write_bytes(gzip.compress("".join(json.dumps(r) + "\n" for r in records).encode(), mtime=0))
        return self.save(role + "-manifest.json", {"schema_version": 1, "cohort_id": "SYNTHETIC-" + role,
            "implementation": role, "split": "training", "artifacts": [{"path": str(path),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "run_id": records[0]["run_id"],
                "trial": 1, "attempt": 1, "status": "complete"}]})

    def execute(self, native=None, candidate=None, mapping=True, version=2):
        plan = {"schema_version": version, "batch_id": "SYNTHETIC-v2", "matrix": self.save("matrix.json", self.matrix),
            "profile": self.save("profile.json", self.profile),
            "holdout_definitions": self.save("held.json", {"schema_version": 1, "definitions": []}),
            "assignments": [{"split": "training", "cell_id": "26/iphone_a/portrait/basic", "expected_trials": [1],
                "scenario_revision": self.assignment_revision, "native": native or self.cohort("native"),
                "candidate": candidate or self.cohort("flutter"), "recipe": self.save("recipe.json", self.recipe),
                "runtime_input_verified": True}]}
        if mapping:
            plan["scenario_map"] = self.save("scenario-map.json", self.mapping)
        ref = self.save("plan.json", plan)
        code, frozen = self.invoke("freeze", ref["path"], "--output-directory", str(self.base / "frozen"))
        if code:
            return frozen
        return self.invoke("run", frozen["index_path"])[1]

    def assert_no_pair(self, result):
        self.assertEqual(result.get("pair_counts", {}).get("paired", 0), 0)
        self.assertEqual(result["verdict"], "FAIL")

    def test_explicit_mapping_pairs_aliases_without_mutating_artifacts(self):
        native, candidate = self.cohort("native"), self.cohort("flutter")
        before = (self.base / "native.jsonl.gz").read_bytes()
        result = self.execute(native, candidate)
        self.assertEqual(result.get("pair_counts", {}).get("paired"), 1, result.get("issues"))
        self.assertEqual(result["phase_counts"], {"PASS": 1, "FAIL": 0, "UNRESOLVED": 0})
        self.assertEqual(result["pairs"][0]["scenario_mapping"]["native"], "native.synthetic.runtime")
        self.assertEqual((self.base / "native.jsonl.gz").read_bytes(), before)
        index = json.loads((self.base / "frozen/index.json").read_text())
        self.assertEqual(index["schema_version"], 2)
        self.assertEqual(index["scenario_map"]["sha256"], hashlib.sha256((self.base / "scenario-map.json").read_bytes()).hexdigest())

    def test_v2_plan_requires_explicit_scenario_map(self):
        result = self.execute(mapping=False)
        self.assert_no_pair(result)
        self.assertIn("scenario map", json.dumps(result).lower())

    def test_similar_unregistered_native_id_is_not_inferred(self):
        native = self.cohort("native", lambda r: r[0].update(scenario_id="native.synthetic.runtime.similar"))
        result = self.execute(native=native)
        self.assert_no_pair(result)
        self.assertIn("scenario", json.dumps(result["issues"]))

    def test_duplicate_matrix_or_source_alias_is_rejected(self):
        for kind in ("duplicate", "ambiguous_alias"):
            with self.subTest(kind=kind):
                self.mapping["entries"] = [copy.deepcopy(self.mapping["entries"][0])]
                extra = copy.deepcopy(self.mapping["entries"][0])
                if kind == "ambiguous_alias":
                    extra.update(matrix="another.case", flutter="different.candidate")
                self.mapping["entries"].append(extra)
                result = self.execute()
                self.assert_no_pair(result)
                self.assertIn("unique", json.dumps(result).lower())

    def test_mapping_entry_revision_must_match_assignment(self):
        self.mapping["entries"][0]["revision"] = 3
        result = self.execute()
        self.assert_no_pair(result)
        self.assertIn("revision", json.dumps(result).lower())

    def test_trace_scenario_revision_must_match_frozen_entry(self):
        result = self.execute(candidate=self.cohort("flutter", lambda r: r[0].update(scenario_revision=3)))
        self.assert_no_pair(result)

    def test_recipe_revision_is_independent_but_must_match_both_traces(self):
        result = self.execute(candidate=self.cohort("flutter", lambda r: r[0]["conditions"].update(recipe_revision=8)))
        self.assert_no_pair(result)

    def test_matching_trace_parameters_cannot_override_frozen_recipe(self):
        def different(records):
            records[0]["conditions"]["parameters"]["scroll_offset_pt"] = 400
        result = self.execute(self.cohort("native", different), self.cohort("flutter", different))
        self.assert_no_pair(result)

    def test_recipe_identity_input_source_and_accessibility_are_checked(self):
        for key, value in (("recipe_id", "SYNTHETIC-other"), ("input_source", "SYNTHETIC-other-input"),
                           ("accessibility", {"reduce_motion": True, "voice_over": False, "content_size_category": "normal"})):
            with self.subTest(key=key):
                self.tmp.cleanup()
                self.setUp()
                result = self.execute(candidate=self.cohort("flutter", lambda r: r[0]["conditions"].update({key: value})))
                self.assert_no_pair(result)

    def test_null_flutter_counterpart_cannot_be_inferred(self):
        self.mapping["entries"][0]["flutter"] = None
        result = self.execute()
        self.assert_no_pair(result)

    def test_scenario_map_hash_tampering_rejects_even_training_only_run(self):
        self.execute()
        (self.base / "scenario-map.json").write_text("{}")
        _, result = self.invoke("run", str(self.base / "frozen/index.json"), "--split", "training")
        self.assert_no_pair(result)
        self.assertIn("hash", json.dumps(result["issues"]))

    def test_v1_plan_cannot_silently_ignore_v2_map_and_conditions(self):
        self.assert_no_pair(self.execute(version=1))

    def test_unknown_conditions_or_semantic_parameter_leakage_rejects_artifact(self):
        for where in ("conditions", "configuration"):
            with self.subTest(where=where):
                self.tmp.cleanup()
                self.setUp()
                result = self.execute(candidate=self.cohort("flutter", lambda r: r[0][where].update(measurement_parameters={})))
                self.assert_no_pair(result)

    def test_empty_or_invalid_mapping_entries_are_rejected(self):
        for entries in ([], ["not-an-entry"], [{"matrix": "synthetic.runtime", "revision": 2}]):
            with self.subTest(entries=entries):
                self.mapping["entries"] = entries
                result = self.execute()
                self.assert_no_pair(result)

    def test_mapped_alias_cannot_bypass_canonical_programmatic_event_contract(self):
        # Break: validating only source aliases skips the canonical scenario gate.
        for defect in ("missing_boundaries", "wrong_targets"):
            with self.subTest(defect=defect):
                self.tmp.cleanup()
                self.setUp()
                def broken(records):
                    if defect == "missing_boundaries":
                        records[:] = [r for r in records if r.get("name") not in ("present.first_visible", "present.completed")]
                    else:
                        requests = [r for r in records if r.get("name") == "detent.requested"]
                        requests[0]["data"]["target"] = "medium"
                        requests[1]["data"]["target"] = "large"
                    for seq, record in enumerate(records):
                        record["seq"] = seq
                result = self.execute(self.cohort("native", broken), self.cohort("flutter", broken))
                self.assert_no_pair(result)

    def test_mapping_equality_does_not_override_an_observed_trajectory_failure(self):
        # Characterization of the retained comparator through the new view boundary.
        def spike(records):
            next(r for r in records if r["type"] == "frame" and r["t_ns"] == 8_000_000)["metrics"]["sheet.y"] = 100
        result = self.execute(candidate=self.cohort("flutter", spike))
        self.assertEqual(result["pair_counts"]["paired"], 1)
        self.assertEqual(result["phase_counts"], {"PASS": 0, "FAIL": 1, "UNRESOLVED": 0})
        self.assertEqual(result["coverage_counts"]["PASS"], 0)

    def test_historical_v1_counts_and_frozen_bytes_are_preserved(self):
        index = fixtures.ROOT / "measurement/runtime/frozen/timing-v1/index.json"
        before = index.read_bytes()
        _, result = self.invoke("run", str(index))
        self.assertEqual(result["required_cells"], 248)
        self.assertEqual(result["required_checks"], 1480)
        self.assertEqual(result["pair_counts"], {"paired": 20, "unresolved": 0})
        self.assertEqual(result["phase_counts"], {"PASS": 0, "FAIL": 120, "UNRESOLVED": 0})
        self.assertEqual(result["coverage_counts"], {"PASS": 0, "FAIL": 2, "UNRESOLVED": 246})
        self.assertEqual(result["issues"], [])
        historical = json.loads((fixtures.ROOT / "artifacts/runtime/timing-v2-report.json").read_text())
        self.assertEqual([phase["analyzer"] for phase in result["phases"]],
                         [phase["analyzer"] for phase in historical["phases"]])
        self.assertEqual(result["coverage"], historical["coverage"])
        self.assertEqual(index.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
