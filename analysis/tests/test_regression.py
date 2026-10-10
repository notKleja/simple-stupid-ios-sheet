"""Coverage tests contain only synthetic trace pairs; no runtime acceptance claims."""
import json
import copy
from pathlib import Path
import subprocess
import sys
import unittest
from tempfile import TemporaryDirectory

from test_compare import trace, config, full_trace, full_config

ROOT = Path(__file__).resolve().parents[2]


def matrix():
    return {"schema_version": 1, "environment_axes": {"ios_major": [26, 27], "device_geometry": ["iphone_a"], "orientation": ["portrait"]},
            "minimum_trials": 1, "cases": [{"id": "linear", "scenario_id": "synthetic.linear", "role": "holdout",
              "required_checks": [{"id": "all", "window": {"start_event": "gesture.ended", "end_event": "trace.end"}}]}]}


def complete_matrix():
    return {"schema_version": 1, "environment_axes": {"ios_major": [26], "device_geometry": ["iphone_a"], "orientation": ["portrait"]},
            "minimum_trials": 1, "cases": [{"id": "linear", "scenario_id": "synthetic.linear", "role": "training",
            "required_check_names": ["opening", "closing"], "required_checks": [
                {"id": "opening", "window": {"start_event": "opening.started", "end_event": "opening.completed"}},
                {"id": "closing", "window": {"start_event": "closing.started", "end_event": "closing.completed"}}
            ]}]}


def gate_records(implementation, fail_close=False):
    """Explicitly synthetic records with simulated runtime markers to exercise gate branches."""
    records = full_trace(implementation)
    template = copy.deepcopy(records[-1])
    for ms in (48, 64, 80):
        frame = copy.deepcopy(template)
        frame["t_ns"] = ms * 1_000_000
        if fail_close and ms == 64:
            frame["metrics"]["sheet.y"] = 100
        records.append(frame)
    for name, ms in (("opening.started", 0), ("opening.completed", 32), ("closing.started", 48), ("closing.completed", 80)):
        records.append({"schema_version": 1, "type": "event", "run_id": records[0]["run_id"],
                        "seq": 0, "t_ns": ms * 1_000_000, "name": name, "data": {}})
    records.sort(key=lambda row: row["t_ns"])
    for seq, row in enumerate(records):
        row["seq"] = seq
    return records


class RegressionTests(unittest.TestCase):
    def run_regression(self, entries, selected_matrix=None):
        request = {"matrix": selected_matrix or matrix(), "entries": entries}
        result = subprocess.run([sys.executable, str(ROOT / "analysis/regression.py"), "--request-stdin"],
                                input=json.dumps(request), text=True, capture_output=True)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return json.loads(result.stdout)

    def file_pairs(self, checks, fail_close=False, selected_matrix=None, settings=None):
        with TemporaryDirectory(prefix="synthetic-gate-test-") as directory:
            base = Path(directory)
            paths = {"native": base / "synthetic-native.jsonl", "candidate": base / "synthetic-candidate.jsonl",
                     "config": base / "synthetic-profile.json", "recipe": base / "synthetic-recipe.json"}
            for role in ("native", "candidate"):
                rows = gate_records("native" if role == "native" else "flutter", fail_close=fail_close and role == "candidate")
                paths[role].write_text("".join(json.dumps(row) + "\n" for row in rows))
            paths["config"].write_text(json.dumps(settings or full_config()))
            paths["recipe"].write_text(json.dumps({"schema_version": 1, "scenario_id": "synthetic.linear", "role": "training",
                                                "preconditions": {}, "provenance": "SYNTHETIC gate test; not runtime evidence"}))
            entries = [{"cell_id": "26/iphone_a/portrait/linear", "trial": 0, "check_id": check,
                        **{role + "_path": str(path) for role, path in paths.items()}, "runtime_input_verified": True} for check in checks]
            return self.run_regression(entries, selected_matrix or complete_matrix())

    def test_empty_manifest_does_not_succeed_vacuously(self):
        result = self.run_regression([])
        self.assertEqual(result["verdict"], "FAIL")
        self.assertEqual(result["required_cells"], 2)
        self.assertEqual(result["unresolved_cells"], 2)

    def test_synthetic_pair_cannot_satisfy_runtime_regression_cell(self):
        result = self.run_regression([{"cell_id": "26/iphone_a/portrait/linear", "check_id": "all", "native": trace(),
                                       "candidate": trace("flutter"), "config": config(), "trial": 0}])
        self.assertEqual(result["accepted_pairs"], 0)
        self.assertIn("synthetic", " ".join(result["issues"]))

    def test_duplicate_trial_cannot_pad_coverage(self):
        entry = {"cell_id": "26/iphone_a/portrait/linear", "check_id": "all", "native": trace(),
                 "candidate": trace("flutter"), "config": config(), "trial": 0}
        result = self.run_regression([entry, entry])
        self.assertIn("duplicate", " ".join(result["issues"]))

    def test_one_passing_phase_does_not_satisfy_whole_case(self):
        result = self.file_pairs(["opening"])
        self.assertEqual(result["verdict"], "FAIL")
        cell = result["coverage"]["26/iphone_a/portrait/linear"]
        self.assertEqual(cell["accepted_trials"], 0)
        self.assertEqual(cell["status"], "PARTIAL")
        self.assertEqual(cell["checks"]["opening"]["accepted_trials"], 1)
        self.assertEqual(cell["checks"]["closing"]["accepted_trials"], 0)

    def test_all_required_checks_may_reuse_same_run_within_one_trial(self):
        result = self.file_pairs(["opening", "closing"])
        self.assertEqual(result["verdict"], "PASS")
        self.assertEqual(result["coverage"]["26/iphone_a/portrait/linear"]["accepted_trials"], 1)

    def test_failed_close_keeps_successful_opening_partial(self):
        result = self.file_pairs(["opening", "closing"], fail_close=True)
        self.assertEqual(result["verdict"], "FAIL")
        cell = result["coverage"]["26/iphone_a/portrait/linear"]
        self.assertEqual(cell["accepted_trials"], 0)
        self.assertEqual(cell["checks"]["opening"]["accepted_trials"], 1)
        self.assertEqual(cell["checks"]["closing"]["accepted_trials"], 0)

    def test_caller_idle_window_cannot_replace_required_closing_window(self):
        settings = full_config()
        settings["window"] = {"start_event": "opening.started", "end_event": "opening.completed"}
        result = self.file_pairs(["closing"], fail_close=True, settings=settings)
        self.assertEqual(result["accepted_pairs"], 0)
        self.assertIn("window", " ".join(result["issues"]))

    def test_required_subcondition_parameters_must_be_observed(self):
        selected = complete_matrix()
        selected["cases"][0]["required_checks"] = [selected["cases"][0]["required_checks"][0]]
        selected["cases"][0]["required_check_names"] = ["opening"]
        selected["cases"][0]["required_checks"][0]["parameters"] = {"reduce_motion": True}
        result = self.file_pairs(["opening"], selected_matrix=selected)
        self.assertEqual(result["accepted_pairs"], 0)
        self.assertIn("subcondition", " ".join(result["issues"]))

    def test_case_without_declared_required_checks_fails_closed(self):
        selected = complete_matrix()
        selected["cases"][0].pop("required_checks")
        result = self.run_regression([], selected)
        self.assertIn("required_checks", " ".join(result["issues"]))

    def test_project_matrix_enforces_programmatic_phases_and_declared_variants(self):
        selected = json.loads((ROOT / "spec/test_matrix.json").read_text())
        result = self.run_regression([], selected)
        self.assertEqual(result.get("required_cells"), 636)
        checks = result["coverage"]["26/iphone_a/portrait/programmatic"]["checks"]
        self.assertEqual(set(checks), {"present", "medium_to_large", "large_to_medium", "dismiss", "side_spacing", "presenter"})
        self.assertEqual(result["required_checks"], 2520)

    def test_missing_declared_variant_cannot_be_ignored_by_required_checks(self):
        selected = complete_matrix()
        selected["cases"][0]["coverage_dimensions"] = {"scroll_offset_pt": [0, 1]}
        selected["cases"][0]["required_checks"][0]["parameters"] = {"scroll_offset_pt": 0}
        result = self.run_regression([], selected)
        self.assertIn("omit subcondition", " ".join(result["issues"]))

    def test_omitted_declared_phase_is_rejected_before_coverage(self):
        selected = complete_matrix()
        selected["cases"][0]["required_checks"].pop()
        result = self.run_regression([], selected)
        self.assertIn("omit required check closing", " ".join(result["issues"]))

    def test_each_cartesian_subcondition_combination_requires_the_full_check_set(self):
        selected = complete_matrix()
        case = selected["cases"][0]
        case["required_check_names"] = ["opening"]
        case["coverage_dimensions"] = {"offset": [0, 1], "origin": ["grabber", "content"]}
        first = copy.deepcopy(case["required_checks"][0])
        second = copy.deepcopy(first)
        first.update({"id": "opening_0_grabber", "check": "opening", "parameters": {"offset": 0, "origin": "grabber"}})
        second.update({"id": "opening_1_content", "check": "opening", "parameters": {"offset": 1, "origin": "content"}})
        case["required_checks"] = [first, second]
        result = self.run_regression([], selected)
        self.assertIn("combination", " ".join(result["issues"]))


if __name__ == "__main__":
    unittest.main()
