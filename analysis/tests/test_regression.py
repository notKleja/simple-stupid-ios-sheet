"""Coverage tests contain only synthetic trace pairs; no runtime acceptance claims."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

from test_compare import trace, config

ROOT = Path(__file__).resolve().parents[2]


def matrix():
    return {"schema_version": 1, "environment_axes": {"ios_major": [26, 27], "device_geometry": ["iphone_a"], "orientation": ["portrait"]},
            "minimum_trials": 1, "cases": [{"id": "linear", "scenario_id": "synthetic.linear", "role": "holdout"}]}


class RegressionTests(unittest.TestCase):
    def run_regression(self, entries):
        request = {"matrix": matrix(), "entries": entries}
        result = subprocess.run([sys.executable, str(ROOT / "analysis/regression.py"), "--request-stdin"],
                                input=json.dumps(request), text=True, capture_output=True)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return json.loads(result.stdout)

    def test_empty_manifest_does_not_succeed_vacuously(self):
        result = self.run_regression([])
        self.assertEqual(result["verdict"], "FAIL")
        self.assertEqual(result["required_cells"], 2)
        self.assertEqual(result["unresolved_cells"], 2)

    def test_synthetic_pair_cannot_satisfy_runtime_regression_cell(self):
        result = self.run_regression([{"cell_id": "26/iphone_a/portrait/linear", "native": trace(),
                                       "candidate": trace("flutter"), "config": config(), "trial": 0}])
        self.assertEqual(result["accepted_pairs"], 0)
        self.assertIn("synthetic", " ".join(result["issues"]))

    def test_duplicate_trial_cannot_pad_coverage(self):
        entry = {"cell_id": "26/iphone_a/portrait/linear", "native": trace(),
                 "candidate": trace("flutter"), "config": config(), "trial": 0}
        result = self.run_regression([entry, entry])
        self.assertIn("duplicate", " ".join(result["issues"]))


if __name__ == "__main__":
    unittest.main()
