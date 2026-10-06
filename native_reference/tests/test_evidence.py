"""Synthetic integrity controls; none of these fixtures are native measurements."""
import copy
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def fixture(trial):
    run = f"synthetic-integrity-{trial}"
    header = {"schema_version": 1, "native_contract_version": 2, "type": "session", "run_id": run,
        "seq": 0, "t_ns": 0, "scenario_id": "native.medium_large.programmatic", "implementation": "native", "evidence_kind": "runtime",
        "os": {"version": "26.4.1", "build": "23E254a"},
        "device": {"model": "TEST_MARKER_ONLY", "runtime_kind": "simulator", "logical_size": {"width": 402, "height": 874}, "physical_size": {"width": 1206, "height": 2622}, "scale": 3, "refresh_hz": 60},
        "environment": {"orientation": "portrait", "safe_area": {"top": 62, "bottom": 34, "left": 0, "right": 0}},
        "configuration": {"trial": trial, "detents": ["fixed320", "medium", "large"], "grabber": True, "surface": "opaque.white", "page_sizing": True,
            "modal_in_presentation": False, "largest_undimmed": None, "presentation_style": "page_sheet", "preferred_content_size": {"width": 320, "height": 320},
            "placement": "automatic", "edge_attached_in_compact_height": False, "width_follows_preferred_content_size": False, "scroll_expansion": True}}
    rows = [header]
    for name, ms, data in [("present.requested", 0, {}), ("present.completed", 600, {}),
            ("detent.requested", 1600, {"target": "large"}), ("detent.requested", 3100, {"target": "medium"}),
            ("dismiss.requested", 4600, {}), ("dismiss.completed", 5200, {})]:
        rows.append({"schema_version": 1, "type": "event", "run_id": run, "seq": 0, "t_ns": ms*1_000_000, "name": name, "data": data})
    for ms in range(0, 4800, 16):
        rows.append({"schema_version": 1, "type": "frame", "run_id": run, "seq": 0, "t_ns": ms*1_000_000,
            "metrics": {"sheet.x": 8, "sheet.y": 415, "sheet.width": 386, "sheet.height": 451, "sheet.left_inset": 8, "sheet.right_inset": 8, "sheet.bottom_inset": 8},
            "state": {"selected_detent": "medium"}})
    rows.sort(key=lambda r: r["t_ns"])
    for seq, row in enumerate(rows):
        row["seq"] = seq
    return rows


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        scripts = self.root / "native_reference/scripts"
        scripts.mkdir(parents=True)
        for source in (ROOT / "native_reference/scripts").glob("*.py"):
            shutil.copyfile(source, scripts / source.name)
        self.rows = [fixture(n) for n in range(1, 11)]

    def tearDown(self):
        self.temp.cleanup()

    def materialize(self):
        artifacts = []
        cohort = self.root / "artifacts/cohort"
        cohort.mkdir(parents=True, exist_ok=True)
        for i, rows in enumerate(self.rows):
            path = cohort / f"trial-{i}.jsonl.gz"
            with gzip.open(path, "wt") as stream:
                stream.write("\n".join(json.dumps(row) for row in rows) + "\n")
            artifacts.append({"path": str(path.relative_to(self.root)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        manifest = {"profiles": [{"trace_count": 10, "session": self.rows[0][0], "artifacts": artifacts}]}
        (self.root / "native_reference/measurements.json").write_text(json.dumps(manifest))
        return cohort

    def validate(self):
        self.materialize()
        return subprocess.run([sys.executable, "-B", "native_reference/scripts/validate_native.py"], cwd=self.root, capture_output=True, text=True)

    def rejected(self):
        result = self.validate()
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_valid_ten_independent_complete_trials(self):
        result = self.validate()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_one_artifact_cannot_claim_ten(self):
        self.rows = self.rows[:1]
        self.rejected()

    def test_duplicate_run_cannot_pad_cohort(self):
        run = self.rows[0][0]["run_id"]
        for row in self.rows[1]:
            row["run_id"] = run
        self.rejected()

    def test_duplicate_trial_cannot_pad_cohort(self):
        self.rows[1][0]["configuration"]["trial"] = 1
        self.rejected()

    def test_os_device_configuration_environment_must_be_homogeneous(self):
        original = copy.deepcopy(self.rows)
        for section, key, value in [("os", "build", "24A434"), ("device", "model", "DIFFERENT"), ("configuration", "grabber", False), ("environment", "orientation", "landscape")]:
            with self.subTest(section=section):
                self.rows = copy.deepcopy(original)
                self.rows[1][0][section][key] = value
                self.rejected()

    def test_missing_rest_window_cannot_be_accepted(self):
        self.rows[1] = [r for r in self.rows[1] if r["type"] != "frame" or not 1_200_000_000 <= r["t_ns"] < 1_600_000_000]
        self.rejected()

    def test_null_required_rest_metric_cannot_be_accepted(self):
        for row in self.rows[1]:
            if row["type"] == "frame" and 1_200_000_000 <= row["t_ns"] < 1_600_000_000:
                row["metrics"]["sheet.y"] = None
                row["unavailable"] = {"sheet.y": "Synthetic unavailable geometry"}
        self.rejected()

    def test_boundary_order_and_target_are_required(self):
        self.rows[1][next(i for i,r in enumerate(self.rows[1]) if r.get("name") == "detent.requested")]["data"]["target"] = "medium"
        self.rejected()

    def test_null_metric_and_state_require_nonempty_reasons(self):
        for section, key in [("metrics", "finger.y"), ("state", "scroll_owner")]:
            with self.subTest(section=section):
                self.rows = [fixture(n) for n in range(1,11)]
                frame = next(r for r in self.rows[0] if r["type"] == "frame")
                frame[section][key] = None
                self.rejected()

    def test_summarizer_rejects_single_trial(self):
        self.rows = self.rows[:1]
        cohort = self.materialize()
        result = subprocess.run([sys.executable, "-B", "native_reference/scripts/summarize_native.py", str(cohort), "--output", str(self.root / "summary.json")], cwd=self.root, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_v2_configuration_cannot_omit_behavior_flags(self):
        for rows in self.rows:
            del rows[0]["configuration"]["scroll_expansion"]
        self.rejected()

    def test_rest_window_gap_cannot_be_hidden_by_remaining_samples(self):
        self.rows[1] = [row for row in self.rows[1] if row["type"] != "frame" or not 1_328_000_000 <= row["t_ns"] <= 1_376_000_000]
        self.rejected()

    def test_terminal_error_rejects_otherwise_complete_run(self):
        rows = self.rows[0]
        rows.append({"schema_version": 1, "type": "event", "run_id": rows[0]["run_id"], "seq": rows[-1]["seq"]+1, "t_ns": rows[-1]["t_ns"], "name": "run.error", "data": {"code": "serialization_failed"}, "terminal": True})
        self.rejected()

    def test_declared_session_cannot_disagree_with_hashed_source(self):
        self.materialize()
        path = self.root / "native_reference/measurements.json"
        manifest = json.loads(path.read_text())
        manifest["profiles"][0]["session"]["device"]["model"] = "FORGED"
        path.write_text(json.dumps(manifest))
        result = subprocess.run([sys.executable, "-B", "native_reference/scripts/validate_native.py"], cwd=self.root, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)

    def test_legacy_requires_named_adapter_and_preserves_original_bytes(self):
        for rows in self.rows:
            del rows[0]["native_contract_version"]
            frame = next(row for row in rows if row["type"] == "frame")
            frame["metrics"]["finger.y"] = None
            frame["state"]["selected_detent"] = "com.apple.UIKit.medium"
        self.materialize()
        before = {p: p.read_bytes() for p in (self.root / "artifacts/cohort").glob("*.gz")}
        result = subprocess.run([sys.executable, "-B", "native_reference/scripts/validate_native.py"], cwd=self.root, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        path = self.root / "native_reference/measurements.json"
        manifest = json.loads(path.read_text())
        manifest["profiles"][0]["legacy_adapter"] = "native-legacy-v1"
        path.write_text(json.dumps(manifest))
        result = subprocess.run([sys.executable, "-B", "native_reference/scripts/validate_native.py"], cwd=self.root, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(all(p.read_bytes() == raw for p, raw in before.items()))


if __name__ == "__main__":
    unittest.main()
