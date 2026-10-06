"""Test ingestion QC against labeled synthetic samples."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

from test_compare import trace

ROOT = Path(__file__).resolve().parents[2]


class InspectTests(unittest.TestCase):
    def test_missing_metric_coverage_is_visible(self):
        records = trace()
        records[3]["metrics"]["sheet.y"] = None
        result = subprocess.run([sys.executable, str(ROOT / "analysis/inspect_trace.py"), "--request-stdin"],
                                input=json.dumps(records), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["metrics"]["sheet.y"]["observed"], 2)
        self.assertEqual(report["metrics"]["sheet.y"]["missing"], 1)
        self.assertEqual(report["parity_proven"], False)
        self.assertAlmostEqual(report["frame_intervals_ms"]["max"], 100)


if __name__ == "__main__":
    unittest.main()
