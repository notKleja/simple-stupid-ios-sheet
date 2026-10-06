"""Synthetic scaled-container geometry, never Apple measurements."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

from test_compare import trace

ROOT = Path(__file__).resolve().parents[2]


def fixture():
    header = trace()[0]
    records = [header]
    for ms, target in ((100, "large"), (300, "medium")):
        records.append({"schema_version": 1, "type": "event", "run_id": header["run_id"],
                        "seq": 0, "t_ns": ms * 1_000_000, "name": "detent.requested", "data": {"target": target}})
    records.append({"schema_version": 1, "type": "event", "run_id": header["run_id"],
                    "seq": 0, "t_ns": 500_000_000, "name": "dismiss.requested", "data": {}})
    for ms, inset in ((0, 10), (50, 10), (100, 10), (150, 5), (200, 0), (250, 0),
                      (300, 0), (350, 5), (400, 10), (450, 10)):
        height = (100 - 50 * inset / 10) * (1 - 2 * inset / 400)
        bottom = inset + .125 * inset * (1 - inset / 10)
        records.append({"schema_version": 1, "type": "frame", "run_id": header["run_id"], "seq": 0,
                        "t_ns": ms * 1_000_000, "metrics": {"sheet.width": 400 - 2 * inset, "sheet.height": height,
                        "sheet.y": 800 - bottom - height, "sheet.left_inset": inset,
                        "sheet.right_inset": inset, "sheet.bottom_inset": bottom}, "state": {}})
    records.sort(key=lambda record: record["t_ns"])
    for i, record in enumerate(records):
        record["seq"] = i
    return records


class SpacingTests(unittest.TestCase):
    def test_side_extent_and_quadratic_bottom_are_checked_independently(self):
        result = subprocess.run([sys.executable, str(ROOT / "analysis/spacing.py"), "--request-stdin"],
                                input=json.dumps([fixture()]), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertFalse(report["parity_proven"])
        self.assertEqual(report["proof_scope"], "synthetic_math_only")
        self.assertLess(report["side"]["max"], 1e-12)
        self.assertLess(report["bottom"]["large"]["quadratic"]["max"], 1e-12)
        self.assertAlmostEqual(report["bottom"]["large"]["equal_side"]["max"], .3125)
        self.assertEqual(report["runs"][0]["parameters"]["M"], 50)
        self.assertEqual(report["runs"][0]["parameters"]["L"], 100)

    def test_unavailable_transition_frame_is_retained_as_unresolved(self):
        records = fixture()
        missing = next(record for record in records if record["type"] == "frame" and record["t_ns"] == 150_000_000)
        missing["metrics"] = {"sheet.y": None}
        missing["unavailable"] = {"sheet.y": "Synthetic missing ancestry"}
        result = subprocess.run([sys.executable, str(ROOT / "analysis/spacing.py"), "--request-stdin"],
                                input=json.dumps([records]), text=True, capture_output=True)
        self.assertEqual(result.returncode, 1)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "unresolved")
        self.assertEqual(len(report["unavailable_frames"]), 1)
        self.assertEqual(report["unavailable_frames"][0]["t_ns"], 150_000_000)
        self.assertFalse(report["parity_proven"])


if __name__ == "__main__":
    unittest.main()
