"""Hand-derived offline contour contracts; not native compositor evidence."""
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from extract_contour import compare_contours, extract_contour

CAL = {"pixels_per_point": 2, "source_id": "literal-fixture", "coordinate_space": "physical_pixels"}


def blank(w, h): return [[False for _ in range(w)] for _ in range(h)]


def contour(mask, source="compositor_raster"):
    return extract_contour(mask, calibration=CAL, source_kind=source)


class RenderedContourTests(unittest.TestCase):
    def test_different_pixel_scales_compare_in_logical_coordinates(self):
        a = blank(5, 5); a[2][2] = True
        b = blank(7, 7); b[3][3] = True
        left = contour(a)
        right = extract_contour(b, calibration={**CAL, "pixels_per_point": 3})
        result = compare_contours(left, right)
        self.assertEqual(result["symmetric_boundary_distance_max_points"], 0)

    def test_symmetric_distance_hand_derived_in_both_directions(self):
        a = contour([[True, True]])
        b = contour([[True]])
        result = compare_contours(a, b)
        self.assertAlmostEqual(result["symmetric_boundary_distance_mean_points"], 1 / 6)
        self.assertEqual(result["symmetric_boundary_distance_max_points"], .5)

    def test_comparison_rejects_missing_or_shadow_provenance(self):
        original = contour([[True]])
        for bad in ({**original, "source_kind": "shadow_path"},
                    {k: v for k, v in original.items() if k != "source_kind"},
                    {**original, "source_id": "   "}):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                compare_contours(original, bad)

    def test_normal_support_flag_cannot_manufacture_oriented_correspondence(self):
        c = contour([[True]])
        result = compare_contours(c, c, maximum_normal_error_supported=True)
        self.assertIsNone(result["maximum_supported_normal_error_points"])
        self.assertEqual(result["normal_error_status"], "unavailable")

    def test_comparison_rejects_invalid_boundary_coordinates(self):
        c = contour([[True]])
        for points in ([(float("nan"), 0)], [(float("inf"), 0)], [(True, 0)], [(0,)], []):
            with self.subTest(points=points), self.assertRaises(ValueError):
                compare_contours(c, {**c, "boundary_physical_pixels": points})

    def test_comparison_rejects_inconsistent_logical_unit_calibration(self):
        c = contour([[True]])
        with self.assertRaisesRegex(ValueError, "logical-point calibration mismatch"):
            compare_contours(c, {**c, "logical_points_per_pixel": 1.0})

    def test_missing_topology_cannot_be_accepted(self):
        c = contour([[True]])
        del c["topology"]
        with self.assertRaises(ValueError):
            compare_contours(c, c)

    def test_square_boundary_and_pixel_point_units(self):
        m = blank(5, 5)
        for y in range(1, 4):
            for x in range(1, 4): m[y][x] = True
        c = contour(m)
        self.assertEqual(len(c["boundary_physical_pixels"]), 8)
        self.assertEqual(c["logical_points_per_pixel"], .5)
        self.assertEqual(c["coordinate_space"], "physical_pixels")

    def test_circle_like_mask_has_hand_derived_boundary(self):
        m = blank(5, 5)
        for y, x in ((1, 2), (2, 1), (2, 2), (2, 3), (3, 2)): m[y][x] = True
        c = contour(m)
        self.assertEqual(set(c["boundary_physical_pixels"]), {(2,1),(1,2),(3,2),(2,3)})

    def test_asymmetric_corner_shape_is_not_collapsed_to_radius(self):
        m = blank(6, 5)
        for y, lo, hi in ((1, 2, 4), (2, 1, 4), (3, 1, 4)):
            for x in range(lo, hi + 1): m[y][x] = True
        c = contour(m)
        self.assertIn((2, 1), c["boundary_physical_pixels"])
        self.assertIn((1, 3), c["boundary_physical_pixels"])
        self.assertFalse("radius" in c)

    def test_corner_disappearance_changes_boundary_and_distance(self):
        rounded = blank(5, 5); square = blank(5, 5)
        for y in range(1, 4):
            for x in range(1, 4): square[y][x] = True
        for y, xs in ((1, (2,)), (2, (1,2,3)), (3,(1,2,3))):
            for x in xs: rounded[y][x] = True
        a, b = contour(rounded), contour(square)
        result = compare_contours(a, b)
        self.assertGreater(result["symmetric_boundary_distance_max_points"], 0)
        self.assertIsNone(result["maximum_supported_normal_error_points"])
        self.assertEqual(result["normal_error_status"], "unavailable")

    def test_disconnected_topology_is_reported_and_rejected_on_compare(self):
        m = blank(5, 3); m[1][0] = True; m[1][4] = True
        c = contour(m)
        self.assertEqual(c["topology"]["foreground_components"], 2)
        joined = blank(5, 3)
        for x in range(5): joined[1][x] = True
        with self.assertRaisesRegex(ValueError, "topology mismatch"):
            compare_contours(c, contour(joined))

    def test_shadow_boundary_rejected(self):
        with self.assertRaisesRegex(ValueError, "shadow/model paths rejected"):
            contour([[True]], "shadow_path")

    def test_absent_calibration_or_source_and_invalid_scale_rejected(self):
        m = [[True]]
        for calibration in (None, {"pixels_per_point": 2, "coordinate_space": "physical_pixels"},
                            {"pixels_per_point": 0, "source_id": "x", "coordinate_space": "physical_pixels"},
                            {"pixels_per_point": float("nan"), "source_id": "x", "coordinate_space": "physical_pixels"}):
            with self.subTest(calibration=calibration), self.assertRaises(ValueError):
                extract_contour(m, calibration=calibration)

    def test_symmetric_distance_is_zero_for_identical_masks(self):
        m = blank(4, 4); m[1][1] = True
        a = contour(m)
        self.assertEqual(compare_contours(a, a)["symmetric_boundary_distance_max_points"], 0)


if __name__ == "__main__": unittest.main()
