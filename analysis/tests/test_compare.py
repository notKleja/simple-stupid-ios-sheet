"""Synthetic mathematics fixtures only; no fixture is a native measurement."""
import json
import copy
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]


def trace(implementation="native", offset=0, values=(0, 10, 20), times=(0, 100, 200)):
    header = {
        "schema_version": 1, "type": "session", "run_id": implementation + "-synthetic",
        "seq": 0, "t_ns": offset, "scenario_id": "synthetic.linear",
        "implementation": implementation, "evidence_kind": "synthetic",
        "os": {"version": "26.4.1", "build": "SYNTHETIC"},
        "device": {"model": "SYNTHETIC", "logical_size": {"width": 400, "height": 800},
                   "physical_size": {"width": 1200, "height": 2400}, "scale": 3, "refresh_hz": 60, "runtime_kind": "synthetic"},
        "environment": {"orientation": "portrait", "safe_area": {"top": 40, "left": 0, "bottom": 30, "right": 0},
                        "size_classes": {"horizontal": "compact", "vertical": "regular"},
                        "status_bar": {"visible": True}, "keyboard": {"visible": False, "frame": None}},
        "configuration": {"recipe_id": "synthetic.linear", "content_height": 1000},
    }
    records = [header, {"schema_version": 1, "type": "event", "run_id": header["run_id"],
                        "seq": 1, "t_ns": offset, "name": "gesture.ended", "data": {}}]
    for i, (ms, y) in enumerate(zip(times, values)):
        records.append({"schema_version": 1, "type": "frame", "run_id": header["run_id"],
                        "seq": i + 2, "t_ns": offset + int(ms * 1_000_000),
                        "metrics": {"sheet.y": y}, "state": {"target_detent": "large"}})
    return records


def config(**extra):
    return {"alignment": {"event": "gesture.ended", "occurrence": 0},
            "metrics": {"sheet.y": {"rms": 1, "max": 2, "final": .25}},
            "states": ["target_detent"], "max_gap_frames": 12, **extra}


def full_config():
    settings = json.loads((ROOT / "measurement/profiles/full.json").read_text())
    settings["alignment"] = {"event": "gesture.ended", "occurrence": 0}
    return settings


def full_trace(implementation="native"):
    """Synthetic provenance-marker simulation for eligibility-gate tests only."""
    records = trace(implementation, times=(0, 16, 32))
    records[0]["evidence_kind"] = "runtime"
    records[0]["device"]["runtime_kind"] = "simulator"
    settings = full_config()
    for record in records:
        if record["type"] == "frame":
            record["metrics"].update({name: 1 if "scale" in name else 0 for name in settings["metrics"]})
            record["state"].update({"selected_detent": "large", "target_detent": "large", "gesture": "none",
                                    "scroll_owner": "sheet", "underlying_hit_test": "blocked"})
    return records


class ComparisonTests(unittest.TestCase):
    def run_compare(self, native=None, candidate=None, settings=None, noise=None):
        request = {"native": native or trace(), "candidate": candidate or trace("flutter"),
                   "config": settings or config()}
        if noise is not None:
            request["noise"] = noise
        result = subprocess.run([sys.executable, str(ROOT / "analysis/compare.py"), "--request-stdin"],
                                input=json.dumps(request), capture_output=True, text=True)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(result.returncode, 0 if report["verdict"] == "PASS" else 1)
        return report

    def test_clock_offset_is_removed_only_by_real_event_boundary(self):
        # Break caught: comparing absolute monotonic clocks across app launches.
        report = self.run_compare(candidate=trace("flutter", offset=9_000_000_000))
        self.assertEqual(report["verdict"], "PASS")
        self.assertEqual(report["alignment"]["clock_offset_ns"], 9_000_000_000)
        self.assertEqual(report["metrics"]["sheet.y"]["rms"], 0)
        self.assertFalse(report["native_parity_eligible"])
        self.assertEqual(report["proof_scope"], "synthetic_math_only")

    def test_absolute_rms_max_and_final_error_are_hand_derived(self):
        # Difference at samples is 1, 2, 3: RMS=sqrt(14/3), mean abs=2.
        report = self.run_compare(candidate=trace("flutter", values=(1, 12, 23)))
        metrics = report["metrics"]["sheet.y"]
        self.assertAlmostEqual(metrics["rms"], 2.160246899469287)
        self.assertEqual(metrics["max"], 3)
        self.assertEqual(metrics["absolute_mean"], 2)
        self.assertEqual(metrics["final"], 3)
        self.assertEqual(report["verdict"], "FAIL")

    def test_interpolation_uses_native_grid_without_duration_normalization(self):
        report = self.run_compare(candidate=trace("flutter", values=(0, 20), times=(0, 200)))
        self.assertEqual(report["metrics"]["sheet.y"]["samples"], 3)
        self.assertEqual(report["metrics"]["sheet.y"]["rms"], 0)

    def test_velocity_error_is_in_points_per_second(self):
        report = self.run_compare(candidate=trace("flutter", values=(0, 11, 22)))
        self.assertAlmostEqual(report["metrics"]["sheet.y"]["velocity_rms"], 10)
        self.assertAlmostEqual(report["metrics"]["sheet.y"]["velocity_max"], 10)

    def test_missing_alignment_boundary_cannot_pass(self):
        candidate = trace("flutter")
        candidate[1]["name"] = "present.requested"
        report = self.run_compare(candidate=candidate)
        self.assertEqual(report["verdict"], "FAIL")
        self.assertIn("boundary", " ".join(report["issues"]))

    def test_truncated_candidate_cannot_hide_tail_error(self):
        report = self.run_compare(candidate=trace("flutter", values=(0, 10), times=(0, 100)))
        self.assertEqual(report["verdict"], "FAIL")
        self.assertIn("coverage", " ".join(report["issues"]))

    def test_missing_metric_is_not_silently_skipped(self):
        candidate = trace("flutter")
        candidate[3]["metrics"]["sheet.y"] = None
        report = self.run_compare(candidate=candidate)
        self.assertEqual(report["verdict"], "FAIL")
        self.assertIn("sheet.y", " ".join(report["issues"]))

    def test_exact_snap_outcome_is_required(self):
        candidate = trace("flutter")
        candidate[-1]["state"]["target_detent"] = "medium"
        report = self.run_compare(candidate=candidate)
        self.assertEqual(report["verdict"], "FAIL")
        self.assertFalse(report["states"]["target_detent"]["match"])

    def test_os_or_environment_mismatch_is_rejected(self):
        for section, key, value in (("os", "version", "27.0"), ("environment", "orientation", "landscape")):
            with self.subTest(section=section):
                candidate = trace("flutter")
                candidate[0][section][key] = value
                report = self.run_compare(candidate=candidate)
                self.assertEqual(report["verdict"], "FAIL")
                self.assertIn(section, " ".join(report["issues"]))

    def test_landmark_timing_uses_native_frame_threshold(self):
        native, candidate = trace(), trace("flutter")
        for records, ms in ((native, 200), (candidate, 220)):
            records.append({"schema_version": 1, "type": "event", "run_id": records[0]["run_id"],
                            "seq": 5, "t_ns": ms * 1_000_000, "name": "detent.settled", "data": {}})
        report = self.run_compare(native, candidate)
        self.assertEqual(report["verdict"], "FAIL")
        self.assertAlmostEqual(report["event_timing"]["detent.settled#0"]["error_ms"], 20)

    def test_large_sampling_gap_is_rejected(self):
        report = self.run_compare(settings=config(max_gap_frames=2))
        self.assertEqual(report["verdict"], "FAIL")
        self.assertIn("gap", " ".join(report["issues"]))

    def test_duplicate_timestamp_and_nonfinite_metrics_are_rejected(self):
        for mutation in ("time", "nan", "seq"):
            candidate = trace("flutter")
            if mutation == "time":
                candidate[3]["t_ns"] = candidate[2]["t_ns"]
            elif mutation == "nan":
                candidate[3]["metrics"]["sheet.y"] = float("nan")
            else:
                candidate[3]["seq"] = candidate[2]["seq"]
            with self.subTest(mutation=mutation):
                self.assertEqual(self.run_compare(candidate=candidate)["verdict"], "FAIL")

    def test_noise_cannot_expand_acceptance_threshold(self):
        noise = {"sheet.y": {"native_trials": [-4, 4] * 5, "candidate_trials": [-4, 4] * 5,
                             "native_run_ids": ["n" + str(i) for i in range(10)],
                             "candidate_run_ids": ["c" + str(i) for i in range(10)]}}
        report = self.run_compare(noise=noise)
        self.assertEqual(report["verdict"], "FAIL")
        self.assertGreater(report["noise"]["sheet.y"]["mean_difference_ci95"], 1)
        self.assertEqual(report["metrics"]["sheet.y"]["limits"]["rms"], 1)

    def test_event_state_sequence_mismatch_is_exact_failure(self):
        native, candidate = trace(), trace("flutter")
        for records, owner in ((native, "sheet"), (candidate, "scroll")):
            records.append({"schema_version": 1, "type": "event", "run_id": records[0]["run_id"],
                            "seq": 5, "t_ns": 200_000_000, "name": "scroll.handoff", "data": {"owner": owner}})
        self.assertEqual(self.run_compare(native, candidate)["verdict"], "FAIL")

    def test_repeated_event_occurrence_is_unambiguous(self):
        native, candidate = trace(), trace("flutter", offset=8_000_000_000)
        for records in (native, candidate):
            records.insert(1, {"schema_version": 1, "type": "event", "run_id": records[0]["run_id"],
                               "seq": 1, "t_ns": records[0]["t_ns"], "name": "gesture.ended", "data": {}})
            for i, record in enumerate(records):
                record["seq"] = i
        settings = config()
        settings["alignment"]["occurrence"] = 1
        self.assertEqual(self.run_compare(native, candidate, settings)["verdict"], "PASS")

    def test_zero_repeat_noise_has_zero_uncertainty(self):
        noise = {"sheet.y": {"native_trials": [0] * 10, "candidate_trials": [0] * 10,
                             "native_run_ids": ["n" + str(i) for i in range(10)],
                             "candidate_run_ids": ["c" + str(i) for i in range(10)]}}
        report = self.run_compare(noise=noise)
        self.assertEqual(report["verdict"], "PASS")
        self.assertEqual(report["noise"]["sheet.y"]["mean_difference_ci95"], 0)

    def test_transient_candidate_state_cannot_hide_between_native_samples(self):
        candidate = trace("flutter", values=(0, 5, 10, 20), times=(0, 50, 100, 200))
        candidate[3]["state"]["target_detent"] = "medium"
        self.assertEqual(self.run_compare(candidate=candidate)["verdict"], "FAIL")

    def test_unknown_runtime_os_build_cannot_earn_parity_acceptance(self):
        native, candidate = trace(), trace("flutter")
        for records in (native, candidate):
            records[0]["evidence_kind"] = "runtime"
            records[0]["device"]["runtime_kind"] = "simulator"
            records[0]["os"]["build"] = None
        self.assertEqual(self.run_compare(native, candidate)["verdict"], "FAIL")

    def test_invalid_request_returns_structured_failure(self):
        result = subprocess.run([sys.executable, str(ROOT / "analysis/compare.py"), "--request-stdin"],
                                input="[]", capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)["verdict"], "FAIL")

    def test_numeric_event_payload_is_not_forced_into_exact_semantics(self):
        native, candidate = trace(), trace("flutter")
        native[1]["data"] = {"target": "large", "resolved_height": 350}
        candidate[1]["data"] = {"target": "large", "resolved_height": 350.25}
        settings = config(exact_event_data={"gesture.ended": ["target"]})
        self.assertEqual(self.run_compare(native, candidate, settings)["verdict"], "PASS")
        candidate[1]["data"]["target"] = "medium"
        self.assertEqual(self.run_compare(native, candidate, settings)["verdict"], "FAIL")

    def test_auxiliary_probe_events_are_explicitly_reported_when_ignored(self):
        native = trace()
        native.append({"schema_version": 1, "type": "event", "run_id": native[0]["run_id"],
                       "seq": 5, "t_ns": 200_000_000, "name": "detent.resolved", "data": {"large": 700}})
        report = self.run_compare(native=native, settings=config(auxiliary_events=["detent.resolved"]))
        self.assertEqual(report["verdict"], "PASS")
        self.assertEqual(report["auxiliary_event_counts"]["native"], {"detent.resolved": 1})

    def test_alignment_event_cannot_be_ignored_as_auxiliary(self):
        report = self.run_compare(settings=config(auxiliary_events=["gesture.ended"]))
        self.assertEqual(report["verdict"], "FAIL")

    def test_diagnostic_runtime_markers_do_not_grant_full_parity_eligibility(self):
        # Synthetic provenance-marker simulation tests the gate, never native behavior.
        native, candidate = trace(), trace("flutter")
        for records in (native, candidate):
            records[0]["evidence_kind"] = "runtime"
            records[0]["device"]["runtime_kind"] = "simulator"
        report = self.run_compare(native, candidate)
        self.assertEqual(report["verdict"], "PASS")
        self.assertFalse(report["native_parity_eligible"])
        self.assertEqual(report["acceptance_scope"], "diagnostic_subset")
        self.assertIn("sheet.radius", report["full_acceptance_missing"])

    def test_candidate_preboundary_sample_can_bracket_native_first_sample(self):
        native = trace(values=(1, 11, 21), times=(10, 110, 210))
        candidate = trace("flutter", values=(-1, 1.5, 11.5, 21.5), times=(-10, 15, 115, 215), offset=100_000_000)
        candidate[0]["t_ns"] = 0
        candidate.sort(key=lambda record: record["t_ns"])
        for i, record in enumerate(candidate):
            record["seq"] = i
        # Header remains first; an observed predecessor is valid interpolation,
        # not extrapolation or a generated sample.
        self.assertEqual(self.run_compare(native, candidate)["verdict"], "PASS")

    def test_phase_window_reports_frames_outside_evaluation(self):
        native = trace(values=(0, 10, 20, 30, 40), times=(0, 100, 200, 300, 400))
        candidate = trace("flutter", values=(None, 10, 20, 30, 40), times=(0, 100, 200, 300, 400))
        for records in (native, candidate):
            for name, ms in (("phase.begin", 100), ("phase.end", 400)):
                records.append({"schema_version": 1, "type": "event", "run_id": records[0]["run_id"], "seq": 0,
                                "t_ns": ms * 1_000_000, "name": name, "data": {}})
            records.sort(key=lambda record: record["t_ns"])
            for i, record in enumerate(records):
                record["seq"] = i
        settings = config(window={"start_event": "phase.begin", "start_occurrence": 0,
                                  "end_event": "phase.end", "end_occurrence": 0})
        report = self.run_compare(native, candidate, settings)
        self.assertEqual(report["verdict"], "PASS")
        self.assertEqual(report["metrics"]["sheet.y"]["samples"], 3)
        self.assertEqual(report["window"]["native_frames_outside"], 2)

    def test_candidate_spike_between_native_samples_counts_in_max_error(self):
        native = trace(values=(0, 0, 0), times=(0, 16, 32))
        candidate = trace("flutter", values=(0, 100, 0, 0), times=(0, 8, 16, 32))
        report = self.run_compare(native, candidate)
        self.assertEqual(report["verdict"], "FAIL")
        self.assertEqual(report["metrics"]["sheet.y"]["max"], 100)
        self.assertEqual(report["metrics"]["sheet.y"]["samples"], 4)
        self.assertEqual(report["comparison_grid"], "union_of_observed_timestamps")

    def test_union_grid_velocity_counts_short_candidate_excursion(self):
        native = trace(values=(0, 0, 0), times=(0, 16, 32))
        candidate = trace("flutter", values=(0, 100, 0, 0), times=(0, 8, 16, 32))
        report = self.run_compare(native, candidate)
        self.assertEqual(report["metrics"]["sheet.y"]["velocity_max"], 12500)

    def test_environment_change_cannot_be_hidden_by_auxiliary_policy(self):
        native, candidate = full_trace(), full_trace("flutter")
        for records in (native, candidate):
            records.append({"schema_version": 1, "type": "event", "run_id": records[0]["run_id"], "seq": 5,
                            "t_ns": 32_000_000, "name": "environment.changed", "data": {"orientation": "landscape"}})
        settings = full_config()
        settings["auxiliary_events"] = ["environment.changed"]
        report = self.run_compare(native, candidate, settings)
        self.assertEqual(report["verdict"], "FAIL")
        self.assertIn("environment", " ".join(report["issues"]))

    def test_empty_semantic_policy_cannot_hide_different_requested_targets(self):
        native, candidate = full_trace(), full_trace("flutter")
        for records, target in ((native, "large"), (candidate, "medium")):
            records.append({"schema_version": 1, "type": "event", "run_id": records[0]["run_id"], "seq": 5,
                            "t_ns": 32_000_000, "name": "detent.requested", "data": {"target": target}})
        settings = full_config()
        settings["exact_event_data"] = {}
        report = self.run_compare(native, candidate, settings)
        self.assertEqual(report["verdict"], "FAIL")
        self.assertFalse(report["native_parity_eligible"])

    def test_full_profile_requires_baseline_semantic_field_policy(self):
        settings = full_config()
        settings["exact_event_data"] = {}
        report = self.run_compare(full_trace(), full_trace("flutter"), settings)
        self.assertFalse(report["native_parity_eligible"])
        self.assertIn("event_data.detent.requested.target", report["full_acceptance_missing"])

    def test_only_approved_probe_markers_can_be_auxiliary(self):
        settings = full_config()
        settings["auxiliary_events"] = ["present.completed"]
        self.assertEqual(self.run_compare(full_trace(), full_trace("flutter"), settings)["verdict"], "FAIL")

    def test_matching_malformed_nested_metadata_is_rejected(self):
        mutations = [
            ("device", "scale", 0), ("device", "scale", True),
            ("device", "logical_size", {"width": "bad", "height": -4}),
            ("device", "physical_size", {"width": 1200, "height": 0}),
            ("device", "model", 12), ("os", "version", 26), ("os", "build", 123),
            ("environment", "safe_area", {"top": "40", "left": 0, "bottom": 30, "right": 0}),
            ("environment", "size_classes", {"horizontal": "tiny", "vertical": "regular"}),
            ("environment", "status_bar", "visible"),
            ("environment", "keyboard", {"visible": "false", "frame": None}),
        ]
        for section, key, value in mutations:
            with self.subTest(section=section, key=key, value=value):
                native, candidate = trace(), trace("flutter")
                for records in (native, candidate):
                    records[0][section][key] = copy.deepcopy(value)
                self.assertEqual(self.run_compare(native, candidate)["verdict"], "FAIL")

    def test_runtime_kind_is_explicit_and_cannot_claim_synthetic_as_runtime(self):
        for kind in (None, "unknown", "synthetic"):
            with self.subTest(kind=kind):
                native, candidate = full_trace(), full_trace("flutter")
                for records in (native, candidate):
                    if kind is None:
                        records[0]["device"].pop("runtime_kind")
                    else:
                        records[0]["device"]["runtime_kind"] = kind
                self.assertEqual(self.run_compare(native, candidate, full_config())["verdict"], "FAIL")


if __name__ == "__main__":
    unittest.main()
