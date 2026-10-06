import copy
import json
import tempfile
import unittest
from pathlib import Path

from measurement.scripts.validate_demo_timeline import TimelineError, validate_timeline


VALID = {
    "schema_version": 1,
    "title": "Native versus Flutter",
    "device": "iPhone 17 Pro",
    "runtime": "iOS 26.4.1",
    "duration_ms": 12000,
    "scenes": [
        {
            "id": "en.intro",
            "language": "en",
            "direction": "ltr",
            "kind": "intro",
            "start_ms": 0,
            "duration_ms": 3000,
            "title": "Synchronized start",
            "subtitle": "Same absolute clock",
            "actions": [],
        },
        {
            "id": "en.page",
            "language": "en",
            "direction": "ltr",
            "kind": "page",
            "start_ms": 3000,
            "duration_ms": 3000,
            "title": "Page sheet",
            "subtitle": "Medium and large",
            "actions": [
                {"at_ms": 100, "type": "present", "detent": "medium"},
                {"at_ms": 1200, "type": "select", "detent": "large"},
                {"at_ms": 2400, "type": "dismiss"},
            ],
        },
        {
            "id": "ar.page",
            "language": "ar",
            "direction": "rtl",
            "kind": "page",
            "start_ms": 6000,
            "duration_ms": 3000,
            "title": "ورقة الصفحة",
            "subtitle": "متوسطة وكبيرة",
            "actions": [
                {"at_ms": 100, "type": "present", "detent": "medium"},
                {"at_ms": 1200, "type": "select", "detent": "large"},
                {"at_ms": 2400, "type": "dismiss"},
            ],
        },
        {
            "id": "ar.outro",
            "language": "ar",
            "direction": "rtl",
            "kind": "outro",
            "start_ms": 9000,
            "duration_ms": 3000,
            "title": "اكتمل العرض",
            "subtitle": "تُحفظ القياسات بشكل منفصل",
            "actions": [],
        },
    ],
}


class TimelineValidationTests(unittest.TestCase):
    def test_valid_timeline_returns_normalized_summary(self):
        result = validate_timeline(copy.deepcopy(VALID))
        self.assertEqual(result["scene_count"], 4)
        self.assertEqual(result["languages"], ["ar", "en"])
        self.assertEqual(result["duration_ms"], 12000)

    def test_overlapping_scenes_are_rejected(self):
        value = copy.deepcopy(VALID)
        value["scenes"][1]["start_ms"] = 2500
        with self.assertRaisesRegex(TimelineError, "overlap"):
            validate_timeline(value)

    def test_missing_arabic_scene_is_rejected(self):
        value = copy.deepcopy(VALID)
        value["scenes"] = [scene for scene in value["scenes"] if scene["language"] == "en"]
        with self.assertRaisesRegex(TimelineError, "English and Arabic"):
            validate_timeline(value)

    def test_arabic_must_be_rtl(self):
        value = copy.deepcopy(VALID)
        value["scenes"][2]["direction"] = "ltr"
        with self.assertRaisesRegex(TimelineError, "Arabic scenes must be rtl"):
            validate_timeline(value)

    def test_actions_must_be_monotonic_and_inside_scene(self):
        value = copy.deepcopy(VALID)
        value["scenes"][1]["actions"][1]["at_ms"] = 50
        with self.assertRaisesRegex(TimelineError, "strictly increasing"):
            validate_timeline(value)
        value = copy.deepcopy(VALID)
        value["scenes"][1]["actions"][-1]["at_ms"] = 3000
        with self.assertRaisesRegex(TimelineError, "inside its scene"):
            validate_timeline(value)

    def test_unknown_kind_or_action_is_rejected(self):
        value = copy.deepcopy(VALID)
        value["scenes"][1]["kind"] = "magic"
        with self.assertRaisesRegex(TimelineError, "unknown kind"):
            validate_timeline(value)
        value = copy.deepcopy(VALID)
        value["scenes"][1]["actions"][0]["type"] = "teleport"
        with self.assertRaisesRegex(TimelineError, "unknown action"):
            validate_timeline(value)

    def test_repository_timeline_is_valid(self):
        path = Path(__file__).parents[1] / "scenarios" / "synchronized_bilingual_demo.json"
        value = json.loads(path.read_text())
        result = validate_timeline(value)
        self.assertGreaterEqual(result["scene_count"], 8)
        self.assertGreaterEqual(result["duration_ms"], 45000)


if __name__ == "__main__":
    unittest.main()
