"""Offline raster contour comparison with explicit physical-pixel calibration.

The input is a binary foreground mask produced from a calibrated compositor
raster crop. This module does not infer clipping from model-layer radii or
shadow paths; callers must name the raster source and supply calibration.
"""
from __future__ import annotations

import math
from typing import Any, Iterable


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _mask_rows(mask: Iterable[Iterable[Any]]) -> list[list[bool]]:
    rows = [list(row) for row in mask]
    _require(bool(rows) and bool(rows[0]), "non-empty raster mask required")
    width = len(rows[0])
    _require(all(len(row) == width for row in rows), "rectangular raster mask required")
    _require(all(type(value) is bool for row in rows for value in row),
             "binary boolean foreground mask required")
    _require(any(value for row in rows for value in row), "foreground contour absent")
    return rows


def _calibration(record: dict[str, Any] | None) -> float:
    _require(isinstance(record, dict), "calibration provenance required")
    scale = record.get("pixels_per_point")
    _require(type(scale) in (int, float) and math.isfinite(scale) and scale > 0,
             "positive finite pixels_per_point calibration required")
    _require(isinstance(record.get("source_id"), str) and record["source_id"].strip(),
             "raster source provenance required")
    _require(record.get("coordinate_space") == "physical_pixels",
             "calibration coordinate_space must be physical_pixels")
    return float(scale)


def extract_contour(mask: Iterable[Iterable[Any]], *, calibration: dict[str, Any] | None,
                    source_kind: str = "compositor_raster") -> dict[str, Any]:
    """Return boundary pixel centers and topology from an opaque binary crop."""
    _require(source_kind == "compositor_raster",
             "only calibrated compositor raster boundaries are eligible; shadow/model paths rejected")
    rows = _mask_rows(mask)
    height, width = len(rows), len(rows[0])
    points = []
    for y in range(height):
        for x in range(width):
            if not rows[y][x]:
                continue
            if any(nx < 0 or ny < 0 or nx >= width or ny >= height or not rows[ny][nx]
                   for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                points.append((x, y))
    scale = _calibration(calibration)
    return {"boundary_physical_pixels": points, "pixels_per_point": scale,
            "source_id": calibration["source_id"], "source_kind": source_kind,
            "coordinate_space": "physical_pixels",
            "logical_points_per_pixel": 1.0 / scale,
            "topology": _topology(rows), "accepted_native_profile": False}


def _topology(mask: list[list[bool]]) -> dict[str, int]:
    height, width = len(mask), len(mask[0])
    def components(target: bool, neighbors: tuple[tuple[int, int], ...]) -> int:
        seen: set[tuple[int, int]] = set()
        count = 0
        for y in range(height):
            for x in range(width):
                if mask[y][x] != target or (x, y) in seen:
                    continue
                count += 1
                stack = [(x, y)]
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop()
                    for dx, dy in neighbors:
                        nx, ny = cx + dx, cy + dy
                        if (0 <= nx < width and 0 <= ny < height and mask[ny][nx] == target
                                and (nx, ny) not in seen):
                            seen.add((nx, ny)); stack.append((nx, ny))
        return count
    cardinal = ((1, 0), (-1, 0), (0, 1), (0, -1))
    return {"foreground_components": components(True, cardinal),
            "background_components": components(False, cardinal)}


def compare_contours(reference: dict[str, Any], candidate: dict[str, Any], *,
                     maximum_normal_error_supported: bool = False) -> dict[str, Any]:
    """Compare symmetric sampled-boundary distance in logical points.

    Both crops must be registered at the same origin (first pixel center).
    This unordered pixel-center representation cannot establish normals or a
    subpixel compositor edge. The legacy support flag cannot change that.
    Distances are diagnostics, never a qualified native PASS.
    """
    _require(isinstance(reference, dict) and isinstance(candidate, dict), "two extracted contours required")
    for contour in (reference, candidate):
        _require(contour.get("coordinate_space") == "physical_pixels", "physical-pixel contour required")
        _require(contour.get("source_kind") == "compositor_raster", "compositor raster provenance required")
        _require(isinstance(contour.get("source_id"), str) and contour["source_id"].strip(), "source provenance required")
        scale = contour.get("pixels_per_point")
        _require(type(scale) in (int, float) and math.isfinite(scale) and scale > 0, "valid contour scale required")
        logical_points_per_pixel = contour.get("logical_points_per_pixel")
        _require(type(logical_points_per_pixel) in (int, float) and
                 math.isfinite(logical_points_per_pixel) and logical_points_per_pixel > 0 and
                 math.isclose(logical_points_per_pixel, 1.0 / scale, rel_tol=0.0, abs_tol=1e-12),
                 "logical-point calibration mismatch")
        _require(bool(contour.get("boundary_physical_pixels")), "non-empty contour boundary required")
        _require(all(isinstance(p, (tuple, list)) and len(p) == 2 and
                     all(type(v) in (int, float) and math.isfinite(v) for v in p)
                     for p in contour["boundary_physical_pixels"]), "finite two-coordinate boundary required")
        topology = contour.get("topology")
        _require(isinstance(topology, dict) and
                 set(topology) == {"foreground_components", "background_components"} and
                 all(type(v) is int and v >= 0 for v in topology.values()) and
                 topology["foreground_components"] > 0, "valid contour topology required")
    _require(reference.get("topology") == candidate.get("topology"), "contour topology mismatch")
    left = [(x / reference["pixels_per_point"], y / reference["pixels_per_point"])
            for x, y in reference["boundary_physical_pixels"]]
    right = [(x / candidate["pixels_per_point"], y / candidate["pixels_per_point"])
             for x, y in candidate["boundary_physical_pixels"]]
    def directed(a: list[tuple[float, float]], b: list[tuple[float, float]]) -> list[float]:
        return [min(math.hypot(x - bx, y - by) for bx, by in b) for x, y in a]
    distances = directed(left, right) + directed(right, left)
    return {"symmetric_boundary_distance_mean_points": sum(distances) / len(distances),
            "symmetric_boundary_distance_max_points": max(distances),
            "maximum_supported_normal_error_points": None,
            "normal_error_status": "unavailable",
            "normal_error_unavailable_reason": "pixel centers lack oriented boundary correspondence",
            "topology_match": True, "physical_pixel_scales": [reference["pixels_per_point"], candidate["pixels_per_point"]],
            "logical_point_units": "each source coordinate divided by its pixels_per_point before distance",
            "accepted_native_profile": False}
