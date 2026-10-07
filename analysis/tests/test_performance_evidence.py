import copy
import unittest

from analysis.performance_evidence import PerformanceEvidenceError, validate_performance_evidence


VALID = {
    "schema_version": 1,
    "runtime_kind": "simulator",
    "native_frame_period_ns": 16_666_667,
    "native_frame_period_source": "observed_display_timestamp",
    "frames": [
        {
            "display_timestamp_ns": 1_000_000_000,
            "flutter_timing_source": "Flutter.FrameTiming",
            "flutter_build_duration_ns": 2_000_000,
            "flutter_raster_duration_ns": 1_000_000,
            "flutter_total_duration_ns": 4_000_000,
        },
        {
            "display_timestamp_ns": 1_016_666_667,
            "delivered_input_timestamp_ns": 1_010_000_000,
            "delivered_input_id": "input-1",
            "delivered_input_source": "delivered_input_callback",
            "flutter_timing_source": "Flutter.FrameTiming",
            "flutter_build_duration_ns": 3_000_000,
            "flutter_raster_duration_ns": 2_000_000,
            "flutter_total_duration_ns": 6_000_000,
        },
        {
            "display_timestamp_ns": 1_033_333_334,
            "visibly_responsive_to_input": True,
            "responsive_input_id": "input-1",
            "visible_response_source": "observed_display_frame",
            "flutter_timing_source": "Flutter.FrameTiming",
            "flutter_build_duration_ns": 4_000_000,
            "flutter_raster_duration_ns": 3_000_000,
            "flutter_total_duration_ns": 8_000_000,
        },
    ],
}


class PerformanceEvidenceTests(unittest.TestCase):
    def test_returns_observed_simulator_latency_and_frame_metrics(self):
        result = validate_performance_evidence(copy.deepcopy(VALID))
        self.assertEqual(result["input_to_first_visible_latency_ns"], 23_333_334)
        self.assertEqual(result["max_display_gap_ns"], 16_666_667)
        self.assertEqual(result["frame_count"], 3)
        self.assertEqual(result["max_flutter_build_duration_ns"], 4_000_000)
        self.assertEqual(result["max_flutter_raster_duration_ns"], 3_000_000)
        self.assertEqual(result["max_flutter_total_duration_ns"], 8_000_000)
        self.assertEqual(result["evidence_scope"], "simulator_observation")
        self.assertEqual(result["physical_input_to_photon"], "unavailable")

    def test_requested_input_cannot_substitute_for_delivered_input(self):
        value = copy.deepcopy(VALID)
        value["frames"][1].pop("delivered_input_timestamp_ns")
        value["frames"][1]["requested_input_timestamp_ns"] = 1_010_000_000
        with self.assertRaisesRegex(PerformanceEvidenceError, "delivered input"):
            validate_performance_evidence(value)

    def test_rejects_missing_visible_response_or_false_zero_timing(self):
        value = copy.deepcopy(VALID)
        value["frames"][2].pop("visibly_responsive_to_input")
        with self.assertRaisesRegex(PerformanceEvidenceError, "visibly responsive"):
            validate_performance_evidence(value)

        value = copy.deepcopy(VALID)
        value["frames"][2]["flutter_raster_duration_ns"] = 0
        with self.assertRaisesRegex(PerformanceEvidenceError, "positive"):
            validate_performance_evidence(value)

        value = copy.deepcopy(VALID)
        value["frames"][2]["flutter_total_duration_ns"] = None
        with self.assertRaisesRegex(PerformanceEvidenceError, "unavailable"):
            validate_performance_evidence(value)

        value = copy.deepcopy(VALID)
        value["frames"][1]["delivered_input_timestamp_ns"] = value["frames"][2]["display_timestamp_ns"]
        with self.assertRaisesRegex(PerformanceEvidenceError, "latency must be positive"):
            validate_performance_evidence(value)

    def test_rejects_observation_gap_longer_than_two_native_frames(self):
        value = copy.deepcopy(VALID)
        value["frames"][2]["display_timestamp_ns"] = 1_066_666_668
        with self.assertRaisesRegex(PerformanceEvidenceError, "two native frames"):
            validate_performance_evidence(value)

    def test_rejects_response_before_delivery_and_non_simulator_identity(self):
        value = copy.deepcopy(VALID)
        value["frames"][1]["delivered_input_timestamp_ns"] = 1_040_000_000
        with self.assertRaisesRegex(PerformanceEvidenceError, "after delivered input"):
            validate_performance_evidence(value)

        value = copy.deepcopy(VALID)
        value["runtime_kind"] = "physical_device"
        with self.assertRaisesRegex(PerformanceEvidenceError, "simulator"):
            validate_performance_evidence(value)

    def test_rejects_requested_or_unlinked_input_response_provenance(self):
        value = copy.deepcopy(VALID)
        value["frames"][1]["delivered_input_source"] = "requested_schedule"
        with self.assertRaisesRegex(PerformanceEvidenceError, "delivered input source"):
            validate_performance_evidence(value)

        value = copy.deepcopy(VALID)
        value["frames"][2]["responsive_input_id"] = "different-input"
        with self.assertRaisesRegex(PerformanceEvidenceError, "input identity"):
            validate_performance_evidence(value)

        value = copy.deepcopy(VALID)
        value["frames"][2]["visible_response_source"] = "self_labeled_callback"
        with self.assertRaisesRegex(PerformanceEvidenceError, "visible response source"):
            validate_performance_evidence(value)

    def test_rejects_unproven_cadence_timing_and_inconsistent_totals(self):
        value = copy.deepcopy(VALID)
        value.pop("native_frame_period_source")
        with self.assertRaisesRegex(PerformanceEvidenceError, "cadence source"):
            validate_performance_evidence(value)

        value = copy.deepcopy(VALID)
        value["frames"][0]["flutter_timing_source"] = "synthetic_fixture"
        with self.assertRaisesRegex(PerformanceEvidenceError, "Flutter.FrameTiming"):
            validate_performance_evidence(value)

        value = copy.deepcopy(VALID)
        value["frames"][0]["flutter_total_duration_ns"] = 1_000_000
        with self.assertRaisesRegex(PerformanceEvidenceError, "total duration"):
            validate_performance_evidence(value)


if __name__ == "__main__":
    unittest.main()
