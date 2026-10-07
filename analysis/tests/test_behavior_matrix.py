"""Executable coverage declarations, not collected native/candidate evidence."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from compare import TraceError
from regression import cells, required_checks, run
from runtime_batch import phase_policy, read_contract_ref

ROOT = Path(__file__).resolve().parents[2]
FAMILIES = ("contour", "grabber", "snap_grid", "finger_transfer", "presenter_interactive", "barrier_curve",
    "nested_scroll", "scroll_momentum", "dismiss_routes", "non_draggable", "navigation", "keyboard_large",
    "hardware_keyboard", "dynamic_medium_large", "stack_layers", "rapid_reverse", "content_fraction_detents",
    "source_view", "resizable", "performance", "rtl", "swiftui_equivalence")


class BehaviorMatrixTests(unittest.TestCase):
    def matrix(self):
        return json.loads((ROOT / "spec/test_matrix.json").read_text())

    def test_every_required_family_expands_on_both_requested_environments(self):
        expanded = cells(self.matrix())
        profile = json.loads((ROOT / "measurement/profiles/full.json").read_text())
        for family in FAMILIES:
            for environment in ("26/iphone_a/portrait", "27/ipad/landscape"):
                with self.subTest(family=family, environment=environment):
                    self.assertIn(environment + "/" + family, expanded)
                    cell = expanded[environment + "/" + family]
                    self.assertEqual(cell["role"], "training")
                    self.assertTrue(cell["check_contracts"])
                    for contract in cell["check_contracts"].values():
                        identifier, policy = phase_policy(profile, contract)
                        self.assertTrue(identifier)
                        self.assertEqual(contract["phase"], policy["phase"])

    def test_cartesian_subconditions_cannot_drop_a_check_combination(self):
        selected = next((case for case in self.matrix()["cases"] if case["id"] == "snap_grid"), None)
        self.assertIsNotNone(selected)
        valid = required_checks(selected)
        self.assertGreaterEqual(len(selected["coverage_dimensions"]), 2)
        self.assertGreater(len(valid), len(selected["required_check_names"]))
        broken = copy.deepcopy(selected)
        broken["required_checks"].pop()
        with self.assertRaises(TraceError):
            required_checks(broken)

    def test_uncollected_expanded_cells_remain_unresolved(self):
        result = run({"matrix": self.matrix(), "entries": []})
        self.assertGreater(result["required_cells"], 248)
        self.assertEqual(result["accepted_pairs"], 0)
        self.assertTrue(all(cell["status"] == "UNRESOLVED" for cell in result["coverage"].values()))

    def test_frozen_v1_denominator_stays_248(self):
        path = ROOT / "measurement/runtime/frozen/timing-v1/index.json"
        index = json.loads(path.read_text())
        matrix, _ = read_contract_ref(index["matrix"], path.parent, legacy=True)
        expanded = cells(matrix)
        self.assertEqual(len(expanded), 248)
        self.assertEqual(sum(len(cell["check_contracts"]) for cell in expanded.values()), 1480)

    def test_original_eight_holdouts_and_assignment_hash_are_unchanged(self):
        baseline = json.loads((ROOT / "measurement/runtime/contracts/v1/test_matrix.json").read_text())
        old = [case for case in baseline["cases"] if case["role"] == "holdout"]
        new = [case for case in self.matrix()["cases"] if case["role"] == "holdout"]
        self.assertEqual(len(new), 8)
        self.assertEqual(new, old)
        path = ROOT / "measurement/runtime/frozen/timing-v1/holdout.json"
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),
            "63623fa506fa7d8a2cb351e6f1cfe6e00dea44863dff6043e86b8a979dba9ea5")
        self.assertEqual(json.loads(path.read_text())["assignments"], [])


if __name__ == "__main__":
    unittest.main()
