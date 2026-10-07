"""Synthetic four-corner gate controls, never rendered/native parity evidence."""
import copy
import gzip
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "analysis"))
import test_conditions_v2 as fixtures
import test_runtime_batch as legacy_fixtures
from regression import run as regression_run
from compare import TraceError, compare, validate_schema

CORNERS = ("sheet.radius.top_left", "sheet.radius.top_right",
           "sheet.radius.bottom_right", "sheet.radius.bottom_left")
VALUES = (11, 22, 33, 44)


class ModelRadiusTests(unittest.TestCase):
    tearDown = fixtures.ConditionsBatchTests.tearDown
    save = fixtures.ConditionsBatchTests.save
    invoke = fixtures.ConditionsBatchTests.invoke
    execute = fixtures.ConditionsBatchTests.execute

    def setUp(self):
        fixtures.ConditionsBatchTests.setUp(self)
        self.matrix["cases"][0]["scenario_id"] = "fixture.model_radius"
        self.recipe["scenario_id"] = "fixture.model_radius"
        self.mapping["entries"][0]["matrix"] = "fixture.model_radius"
        self.rules = copy.deepcopy(self.recipe["conditions"]["applicability"]["present"])
        self.rules["model_radius"] = "required"
        self.profile["applicability_policies"]["SYNTHETIC-model-radius"] = {
            "phase": "geometry", "observables": copy.deepcopy(self.rules)}
        self.contract = self.matrix["cases"][0]["required_checks"][0]
        self.contract.update(check="model_radius", phase="geometry",
            applicability_policy_id="SYNTHETIC-model-radius",
            window={"start_event": "geometry.radius.started", "end_event": "geometry.radius.completed"})
        self.matrix["cases"][0]["required_check_names"] = ["model_radius"]
        self.recipe["conditions"]["applicability"] = {"geometry": copy.deepcopy(self.rules)}

    def cohort(self, role, change=None):
        def declared(records):
            records[0]["conditions"]["applicability"] = {"geometry": copy.deepcopy(self.rules)}
            for row in records:
                if row.get("name") == "present.requested": row["name"] = "geometry.radius.started"
                if row.get("name") == "detent.requested" and row["data"]["target"] == "large":
                    row["name"] = "geometry.radius.completed"
                if row["type"] == "frame":
                    row["metrics"].update(dict(zip(CORNERS, VALUES)))
                    row["metrics"]["sheet.radius"] = None
                    row["unavailable"] = {"sheet.radius": "SYNTHETIC asymmetric corners; no scalar"}
            if change: change(records)
        return fixtures.ConditionsBatchTests.cohort(self, role, declared)

    def test_literal_four_corner_pass_does_not_require_scalar(self):
        result = self.execute()
        self.assertEqual(result.get("phase_counts"), {"PASS": 1, "FAIL": 0, "UNRESOLVED": 0}, result)
        report = result["phases"][0]["analyzer"]
        self.assertEqual(report["check_family"], "model_radius")
        self.assertFalse(report["native_parity_eligible"])
        for key in CORNERS: self.assertEqual(report["metrics"][key]["max"], 0)

    def test_clockwise_bottom_corner_swap_is_an_observed_failure(self):
        def swapped(records):
            for row in records:
                if row["type"] == "frame":
                    row["metrics"][CORNERS[2]], row["metrics"][CORNERS[3]] = 44, 33
        result = self.execute(candidate=self.cohort("flutter", swapped))
        self.assertEqual(result.get("phase_counts", {}).get("FAIL"), 1, result)
        self.assertEqual(result["phases"][0]["analyzer"]["metrics"][CORNERS[2]]["max"], 11)

    def test_one_missing_corner_in_either_trace_stays_unresolved(self):
        def missing(records):
            for row in records:
                if row["type"] == "frame" and row["t_ns"] == 8_000_000:
                    row["metrics"].pop(CORNERS[2])
        for role in ("native", "flutter"):
            with self.subTest(role=role):
                self.tmp.cleanup(); self.setUp()
                result = self.execute(**{"native" if role == "native" else "candidate": self.cohort(role, missing)})
                self.assertEqual(result.get("phase_counts", {}).get("UNRESOLVED"), 1, result)

    def test_scalar_only_even_equal_corners_cannot_satisfy_family(self):
        def scalar(records):
            for row in records:
                if row["type"] == "frame":
                    for key in CORNERS: row["metrics"].pop(key)
                    row["metrics"]["sheet.radius"] = 38
        result = self.execute(self.cohort("native", scalar), self.cohort("flutter", scalar))
        self.assertEqual(result.get("phase_counts", {}).get("UNRESOLVED"), 1, result)

    def test_asymmetric_single_corner_mismatch_fails(self):
        def mismatch(records):
            for row in records:
                if row["type"] == "frame": row["metrics"][CORNERS[0]] = 12
        result = self.execute(candidate=self.cohort("flutter", mismatch))
        self.assertEqual(result.get("phase_counts", {}).get("FAIL"), 1, result)

    def test_explicit_null_with_reason_remains_unresolved(self):
        def absent(records):
            for row in records:
                if row["type"] == "frame":
                    row["metrics"][CORNERS[0]] = None
                    row["unavailable"][CORNERS[0]] = "SYNTHETIC unavailable observer"
        result = self.execute(candidate=self.cohort("flutter", absent))
        self.assertEqual(result.get("phase_counts", {}).get("UNRESOLVED"), 1, result)

    def test_model_corners_cannot_satisfy_rendered_contour(self):
        self.rules.pop("model_radius")
        self.rules["contour"] = "required"
        self.profile["applicability_policies"]["SYNTHETIC-model-radius"] = {"phase": "contour", "observables": self.rules}
        self.contract.update(check="contour", phase="contour",
            window={"start_event": "contour.sample.started", "end_event": "contour.sample.completed"})
        self.matrix["cases"][0]["required_check_names"] = ["contour"]
        self.recipe["conditions"]["applicability"] = {"contour": copy.deepcopy(self.rules)}
        def contour(records):
            records[0]["conditions"]["applicability"] = {"contour": copy.deepcopy(self.rules)}
            for row in records:
                if row.get("name") == "geometry.radius.started": row["name"] = "contour.sample.started"
                if row.get("name") == "geometry.radius.completed": row["name"] = "contour.sample.completed"
                if row["type"] == "frame": row["metrics"]["sheet.radius"] = 38
        result = self.execute(self.cohort("native", contour), self.cohort("flutter", contour))
        self.assertEqual(result["phase_counts"]["UNRESOLVED"], 1)
        self.assertIn("contour", result["phases"][0]["applicability"]["unresolved_observables"])

    def test_not_applicable_phase_does_not_compare_corner_values(self):
        self.rules["model_radius"] = "not_applicable"
        self.profile["applicability_policies"]["SYNTHETIC-model-radius"]["phase"] = "present"
        self.profile["applicability_policies"]["SYNTHETIC-model-radius"]["observables"] = copy.deepcopy(self.rules)
        self.contract.update(check="present", phase="present",
            window={"start_event": "present.requested", "end_event": "detent.requested"})
        self.matrix["cases"][0]["required_check_names"] = ["present"]
        self.recipe["conditions"]["applicability"] = {"present": copy.deepcopy(self.rules)}
        for key in CORNERS: self.profile["metrics"][key] = {"max": .5, "final": .5}
        def inapplicable(records):
            records[0]["conditions"]["applicability"] = {"present": copy.deepcopy(self.rules)}
            for row in records:
                if row.get("name") == "geometry.radius.started": row["name"] = "present.requested"
                if row.get("name") == "geometry.radius.completed": row["name"] = "detent.requested"
                if row["type"] == "frame":
                    row["metrics"]["sheet.radius"] = 38
                    for key in CORNERS:
                        row["metrics"][key] = None
                        row["unavailable"][key] = "SYNTHETIC not applicable in presentation"
        result = self.execute(self.cohort("native", inapplicable), self.cohort("flutter", inapplicable))
        self.assertEqual(result.get("phase_counts", {}).get("PASS"), 1, result)
        self.assertFalse(set(CORNERS) & result["phases"][0]["analyzer"]["metrics"].keys())

    def test_required_model_group_cannot_pass_without_its_comparison_family(self):
        self.contract["check"] = "present"
        self.matrix["cases"][0]["required_check_names"] = ["present"]
        def scalar(records):
            for row in records:
                if row["type"] == "frame": row["metrics"]["sheet.radius"] = 38
        result = self.execute(self.cohort("native", scalar), self.cohort("flutter", scalar))
        self.assertEqual(result.get("phase_counts", {}).get("PASS", 0), 0, result)


class CornerSchemaTests(unittest.TestCase):
    def setUp(self):
        self.schema = json.loads((ROOT / "measurement/schema/trace-v2.schema.json").read_text())

    def frame(self):
        return {"schema_version": 1, "type": "frame", "run_id": "SYNTHETIC", "seq": 1, "t_ns": 0,
                "metrics": dict(zip(CORNERS, VALUES)), "state": {}}

    def test_optional_corners_and_nonnegative_finite_values(self):
        validate_schema({**self.frame(), "metrics": {}}, self.schema)
        validate_schema(self.frame(), self.schema)
        for corner in CORNERS:
            for value in (-1, True, float("inf"), float("nan"), "38"):
                row = self.frame(); row["metrics"][corner] = value
                with self.subTest(corner=corner, value=value), self.assertRaises(TraceError): validate_schema(row, self.schema)

    def test_null_corner_requires_its_own_nonempty_reason(self):
        for reason in (None, "", "   "):
            row = self.frame(); row["metrics"][CORNERS[2]] = None
            if reason is not None: row["unavailable"] = {CORNERS[2]: reason}
            with self.subTest(reason=reason), self.assertRaises(TraceError): validate_schema(row, self.schema)
        row = self.frame(); row["metrics"][CORNERS[2]] = None
        row["unavailable"] = {CORNERS[2]: "SYNTHETIC observer unavailable"}
        validate_schema(row, self.schema)


class LegacyRadiusBypassTests(unittest.TestCase):
    tearDown = legacy_fixtures.RuntimeBatchTests.tearDown
    save = legacy_fixtures.RuntimeBatchTests.save
    invoke = legacy_fixtures.RuntimeBatchTests.invoke
    execute = legacy_fixtures.RuntimeBatchTests.execute
    cohort = legacy_fixtures.RuntimeBatchTests.cohort

    def setUp(self):
        legacy_fixtures.RuntimeBatchTests.setUp(self)
        self.matrix["cases"][0]["required_check_names"] = ["model_radius"]
        self.matrix["cases"][0]["required_checks"][0]["check"] = "model_radius"

    def test_v1_matrix_cannot_label_a_scalar_pass_as_model_radius(self):
        result = self.execute(self.cohort("native", [(1, 1, {})]), self.cohort("flutter", [(1, 1, {})]))
        self.assertEqual(result.get("coverage_counts", {}).get("PASS", 0), 0, result)
        self.assertFalse(result["parity_proven"])

    def test_regression_matrix_cannot_label_scalar_comparison_as_model_radius(self):
        native = json.loads(Path(self.cohort("native", [(1, 1, {})])["path"]).read_text())["artifacts"][0]
        candidate = json.loads(Path(self.cohort("flutter", [(1, 1, {})])["path"]).read_text())["artifacts"][0]
        result = regression_run({"matrix": self.matrix, "entries": [{
            "cell_id": "26/iphone_a/portrait/basic", "trial": 1, "check_id": "present",
            "native_path": native["path"], "native_sha256": native["sha256"],
            "candidate_path": candidate["path"], "candidate_sha256": candidate["sha256"],
            "config_path": self.save("entry-profile.json", self.profile)["path"],
            "recipe_path": self.save("entry-recipe.json", self.recipe)["path"],
            "runtime_input_verified": True}]})
        self.assertEqual(result["accepted_pairs"], 0, result)
        self.assertFalse(result["parity_proven"])


class DirectV2ValidationTests(unittest.TestCase):
    tearDown = legacy_fixtures.RuntimeBatchTests.tearDown
    save = legacy_fixtures.RuntimeBatchTests.save

    def setUp(self):
        legacy_fixtures.RuntimeBatchTests.setUp(self)

    def records(self, role, bad_value=44, declared=True):
        records = legacy_fixtures.rows(role)
        if declared:
            records[0]["conditions"] = fixtures.conditions()
            for row in records:
                if row["type"] == "frame":
                    row["metrics"].update(dict(zip(CORNERS, VALUES)))
                    row.setdefault("unavailable", {})
                    if row["t_ns"] == 80_000_000:
                        row["metrics"][CORNERS[3]] = bad_value
        return records

    def comparison(self, native, candidate):
        settings = {**self.profile, "window": self.matrix["cases"][0]["required_checks"][0]["window"]}
        self.assertNotIn("check_family", settings)
        return compare({"native": native, "candidate": candidate, "config": settings})

    def regression(self, native, candidate):
        paths = {}
        for role, records in (("native", native), ("candidate", candidate)):
            path = self.base / (role + "-direct-v2.jsonl.gz")
            path.write_bytes(gzip.compress("".join(json.dumps(row) + "\n" for row in records).encode(), mtime=0))
            paths[role + "_path"] = str(path)
        return regression_run({"matrix": self.matrix, "entries": [{
            "cell_id": "26/iphone_a/portrait/basic", "trial": 1, "check_id": "present", **paths,
            "config_path": self.save("direct-profile.json", self.profile)["path"],
            "recipe_path": self.save("direct-recipe.json", self.recipe)["path"],
            "runtime_input_verified": True}]})

    def test_direct_compare_rejects_negative_corner_outside_window_without_family(self):
        for role in ("native", "flutter"):
            with self.subTest(role=role):
                report = self.comparison(self.records("native", -1 if role == "native" else 44),
                                         self.records("flutter", -1 if role == "flutter" else 44))
                self.assertEqual(report["verdict"], "FAIL", report)
                self.assertIn(CORNERS[3], " ".join(report["issues"]))

    def test_direct_compare_rejects_null_without_reason_outside_window_without_family(self):
        report = self.comparison(self.records("native"), self.records("flutter", None))
        self.assertEqual(report["verdict"], "FAIL", report)
        self.assertIn(CORNERS[3], " ".join(report["issues"]))

    def test_regression_rejects_negative_corner_outside_window_without_family(self):
        result = self.regression(self.records("native", -1), self.records("flutter"))
        self.assertEqual(result["accepted_pairs"], 0, result)
        self.assertIn(CORNERS[3], " ".join(result["pairs"][0]["report"]["issues"]))

    def test_regression_rejects_null_without_reason_outside_window_without_family(self):
        result = self.regression(self.records("native"), self.records("flutter", None))
        self.assertEqual(result["accepted_pairs"], 0, result)
        self.assertIn(CORNERS[3], " ".join(result["pairs"][0]["report"]["issues"]))

    def test_valid_conditions_trace_still_compares_without_radius_family(self):
        report = self.comparison(self.records("native"), self.records("flutter"))
        self.assertEqual(report["verdict"], "PASS", report)
        self.assertEqual(self.regression(self.records("native"), self.records("flutter"))["accepted_pairs"], 1)

    def test_genuine_conditionless_v1_keeps_existing_validation(self):
        report = self.comparison(self.records("native", declared=False), self.records("flutter", declared=False))
        self.assertEqual(report["verdict"], "PASS", report)
        self.assertEqual(self.regression(self.records("native", declared=False),
                                         self.records("flutter", declared=False))["accepted_pairs"], 1)


if __name__ == "__main__": unittest.main()
