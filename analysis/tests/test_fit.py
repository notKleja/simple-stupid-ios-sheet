"""Synthetic model fits; these do not establish an Apple spring."""
import json
import math
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]


class FitTests(unittest.TestCase):
    def fit(self, request):
        result = subprocess.run([sys.executable, str(ROOT / "analysis/fit.py")],
                                input=json.dumps(request), text=True, capture_output=True)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return json.loads(result.stdout)

    def test_damped_fit_recovers_known_synthetic_initial_velocity(self):
        # Independent analytic fixture: x=1+exp(-2t)*(cos(8t)+0.5*sin(8t)).
        # lambda=2, wd=8, wn=sqrt(68), zeta=2/sqrt(68), v0=2.
        times = [i / 100 for i in range(101)]
        values = [1 + math.exp(-2 * t) * (math.cos(8 * t) + .5 * math.sin(8 * t)) for t in times]
        result = self.fit({"model": "underdamped_spring", "evidence_kind": "synthetic", "times_s": times,
                           "values": values, "target": 1, "omega_candidates": [7, math.sqrt(68), 9],
                           "zeta_candidates": [.2, 2 / math.sqrt(68), .5]})
        self.assertAlmostEqual(result["omega_n"], math.sqrt(68))
        self.assertAlmostEqual(result["zeta"], 2 / math.sqrt(68))
        self.assertAlmostEqual(result["initial_velocity"], 2)
        self.assertLess(result["rms"], 1e-12)
        self.assertEqual(result["proof_scope"], "synthetic_math_only")

    def test_linear_transfer_function_reports_residual_not_native_truth(self):
        result = self.fit({"model": "linear_transfer", "evidence_kind": "synthetic",
                           "finger_displacement": [0, 10, 20, 30], "sheet_displacement": [2, 7, 12, 17]})
        self.assertEqual(result["gain"], .5)
        self.assertEqual(result["intercept"], 2)
        self.assertEqual(result["rms"], 0)

    def test_unsupported_or_unidentifiable_models_are_rejected(self):
        for request in ({"model": "spring", "evidence_kind": "synthetic"},
                        {"model": "linear_transfer", "evidence_kind": "synthetic", "finger_displacement": [1, 1], "sheet_displacement": [1, 2]}):
            with self.subTest(request=request):
                self.assertEqual(self.fit(request)["status"], "unresolved")


if __name__ == "__main__":
    unittest.main()
