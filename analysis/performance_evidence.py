"""Validate bounded simulator frame-pacing and input-latency observations."""

from __future__ import annotations

from typing import Any


class PerformanceEvidenceError(ValueError):
    """Raised when timing evidence cannot support the requested observation."""


_TIMING_FIELDS = (
    "flutter_build_duration_ns",
    "flutter_raster_duration_ns",
    "flutter_total_duration_ns",
)
_CADENCE_SOURCE = "observed_display_timestamp"
_DELIVERED_INPUT_SOURCE = "delivered_input_callback"
_VISIBLE_RESPONSE_SOURCE = "observed_display_frame"
_FLUTTER_TIMING_SOURCE = "Flutter.FrameTiming"


def _positive_integer(value: Any, label: str) -> int:
    if type(value) is not int or value <= 0:
        raise PerformanceEvidenceError(f"{label} must be a positive integer; zero is not timing evidence")
    return value


def _timing(frame: dict[str, Any], field: str, index: int) -> int:
    value = frame.get(field)
    if value is None:
        raise PerformanceEvidenceError(f"frame {index} {field} is unavailable")
    return _positive_integer(value, f"frame {index} {field}")


def validate_performance_evidence(value: dict[str, Any]) -> dict[str, Any]:
    """Return qualified simulator metrics or reject incomplete timing observations.

    This validates a deliberately narrow evidence shape.  It establishes only
    recorder-domain simulator observations, never physical input-to-photon
    latency or a native/Flutter parity result.
    """

    if value.get("schema_version") != 1:
        raise PerformanceEvidenceError("schema_version must equal 1")
    if value.get("runtime_kind") != "simulator":
        raise PerformanceEvidenceError("runtime_kind must be simulator for this qualified scope")
    native_frame_period = _positive_integer(value.get("native_frame_period_ns"), "native_frame_period_ns")
    if value.get("native_frame_period_source") != _CADENCE_SOURCE:
        raise PerformanceEvidenceError("native frame cadence source must be observed_display_timestamp")
    frames = value.get("frames")
    if not isinstance(frames, list) or not frames:
        raise PerformanceEvidenceError("frames must be a nonempty array")

    delivered_inputs: list[tuple[str, int]] = []
    responsive_displays: list[tuple[str, int]] = []
    previous_display: int | None = None
    max_gap = 0
    maxima = {field: 0 for field in _TIMING_FIELDS}
    for index, frame in enumerate(frames):
        if not isinstance(frame, dict):
            raise PerformanceEvidenceError(f"frame {index} must be an object")
        display = _positive_integer(frame.get("display_timestamp_ns"), f"frame {index} display_timestamp_ns")
        if previous_display is not None:
            gap = display - previous_display
            if gap <= 0:
                raise PerformanceEvidenceError("display timestamps must be strictly increasing")
            if gap > native_frame_period * 2:
                raise PerformanceEvidenceError("display observation gap exceeds two native frames")
            max_gap = max(max_gap, gap)
        previous_display = display

        if frame.get("flutter_timing_source") != _FLUTTER_TIMING_SOURCE:
            raise PerformanceEvidenceError(f"frame {index} timing source must be Flutter.FrameTiming")
        durations = {field: _timing(frame, field, index) for field in _TIMING_FIELDS}
        if durations["flutter_total_duration_ns"] < durations["flutter_build_duration_ns"]:
            raise PerformanceEvidenceError("Flutter total duration must be at least build duration")
        if durations["flutter_total_duration_ns"] < durations["flutter_raster_duration_ns"]:
            raise PerformanceEvidenceError("Flutter total duration must be at least raster duration")
        for field, duration in durations.items():
            maxima[field] = max(maxima[field], duration)

        if "requested_input_timestamp_ns" in frame and "delivered_input_timestamp_ns" not in frame:
            raise PerformanceEvidenceError("requested input cannot substitute for delivered input")
        if "delivered_input_timestamp_ns" in frame:
            delivered = _positive_integer(frame["delivered_input_timestamp_ns"], f"frame {index} delivered_input_timestamp_ns")
            input_id = frame.get("delivered_input_id")
            if not isinstance(input_id, str) or not input_id:
                raise PerformanceEvidenceError("delivered input requires a nonempty input identity")
            if frame.get("delivered_input_source") != _DELIVERED_INPUT_SOURCE:
                raise PerformanceEvidenceError("delivered input source must be delivered_input_callback")
            delivered_inputs.append((input_id, delivered))
        if frame.get("visibly_responsive_to_input") is True:
            input_id = frame.get("responsive_input_id")
            if not isinstance(input_id, str) or not input_id:
                raise PerformanceEvidenceError("visible response requires a nonempty input identity")
            if frame.get("visible_response_source") != _VISIBLE_RESPONSE_SOURCE:
                raise PerformanceEvidenceError("visible response source must be observed_display_frame")
            responsive_displays.append((input_id, display))

    if len(delivered_inputs) != 1:
        raise PerformanceEvidenceError("exactly one delivered input timestamp is required")
    if not responsive_displays:
        raise PerformanceEvidenceError("a first visibly responsive frame is required")

    delivered_id, delivered = delivered_inputs[0]
    if any(input_id != delivered_id for input_id, _ in responsive_displays):
        raise PerformanceEvidenceError("visible response must link to the delivered input identity")
    first_visible = next((display for _, display in responsive_displays if display >= delivered), None)
    if first_visible is None:
        raise PerformanceEvidenceError("first visibly responsive frame must occur after delivered input")
    if any(display < delivered for _, display in responsive_displays):
        raise PerformanceEvidenceError("visibly responsive frame must occur after delivered input")
    latency = first_visible - delivered
    if latency <= 0:
        raise PerformanceEvidenceError("input-to-first-visible latency must be positive")

    return {
        "evidence_scope": "simulator_observation",
        "physical_input_to_photon": "unavailable",
        "frame_count": len(frames),
        "max_display_gap_ns": max_gap,
        "input_to_first_visible_latency_ns": latency,
        "max_flutter_build_duration_ns": maxima["flutter_build_duration_ns"],
        "max_flutter_raster_duration_ns": maxima["flutter_raster_duration_ns"],
        "max_flutter_total_duration_ns": maxima["flutter_total_duration_ns"],
    }
