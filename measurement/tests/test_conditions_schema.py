"""Contract tests use synthetic controls and one immutable historical header."""
import gzip
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
from analysis.compare import TraceError, validate_schema


class ConditionsSchemaTests(unittest.TestCase):
    def schema(self):
        path = ROOT / "measurement/schema/trace-v2.schema.json"
        # Before implementation, exercise the actual old schema, not a missing-file error.
        return json.loads((path if path.exists() else ROOT / "measurement/schema/trace.schema.json").read_text())

    def header(self):
        return {"schema_version": 1, "type": "session", "run_id": "SYNTHETIC-schema-only", "seq": 0, "t_ns": 0,
            "scenario_id": "synthetic.conditions", "implementation": "native", "evidence_kind": "synthetic",
            "os": {"version": "26.4.1", "build": "SYNTHETIC"},
            "device": {"model": "SYNTHETIC", "runtime_kind": "synthetic", "scale": 3, "refresh_hz": 60,
                "logical_size": {"width": 400, "height": 800}, "physical_size": {"width": 1200, "height": 2400}},
            "environment": {"orientation": "portrait", "safe_area": {"top": 40, "left": 0, "bottom": 30, "right": 0},
                "size_classes": {"horizontal": "compact", "vertical": "regular"}, "status_bar": {"hidden": False},
                "keyboard": {"visible": False, "frame": None}},
            "configuration": {"trial": 1, "detents": ["fixed320", "medium", "large"], "surface": "opaque.white",
                "grabber": True, "page_sizing": True, "modal_in_presentation": False, "largest_undimmed": None,
                "presentation_style": "page_sheet", "preferred_content_size": {"width": 320, "height": 320},
                "placement": "automatic", "edge_attached_in_compact_height": False,
                "width_follows_preferred_content_size": False, "scroll_expansion": True},
            "conditions": {"recipe_id": "SYNTHETIC", "recipe_revision": 2, "parameters": {"scroll_offset_pt": 1},
                "input_source": "synthetic-delivered-input",
                "accessibility": {"reduce_motion": False, "voice_over": False, "content_size_category": "normal"},
                "applicability": {"present": {"target_detent": "required", "scroll": "not_applicable",
                    "hit_testing": "not_applicable", "keyboard": "not_applicable", "stack_layers": "not_applicable",
                    "contour": "not_applicable", "performance": "not_applicable"}}}}

    def test_valid_conditions_leave_semantic_configuration_exact(self):
        validate_schema(self.header(), self.schema())

    def test_unknown_condition_keys_are_rejected(self):
        header = self.header()
        header["conditions"]["guessed_native_constant"] = 24
        with self.assertRaises(TraceError):
            validate_schema(header, self.schema())

    def test_all_six_condition_keys_are_required(self):
        for key in ("recipe_id", "recipe_revision", "parameters", "input_source", "accessibility", "applicability"):
            header = self.header()
            del header["conditions"][key]
            with self.subTest(key=key), self.assertRaises(TraceError):
                validate_schema(header, self.schema())

    def test_invalid_applicability_values_and_unknown_observables_are_rejected(self):
        for key, value in (("target_detent", "measured"), ("invented_observable", "required")):
            header = self.header()
            header["conditions"]["applicability"]["present"][key] = value
            with self.subTest(key=key), self.assertRaises(TraceError):
                validate_schema(header, self.schema())

    def test_measurement_parameters_are_not_semantic_configuration(self):
        header = self.header()
        header["configuration"]["measurement_parameters"] = {"scroll_offset_pt": 1}
        with self.assertRaises(TraceError):
            validate_schema(header, self.schema())

    def test_v2_schema_requires_conditions_and_typed_configuration(self):
        for change in (lambda h: h.pop("conditions"), lambda h: h["configuration"].update(grabber="true")):
            header = self.header()
            change(header)
            with self.subTest(header=header), self.assertRaises(TraceError):
                validate_schema(header, self.schema())

    def test_historical_v1_header_still_validates_without_conditions(self):
        path = next((ROOT / "artifacts/native/timing/ios26_strict_anchored").glob("*.jsonl.gz"))
        original = path.read_bytes()
        schema = json.loads((ROOT / "measurement/schema/trace.schema.json").read_text())
        for line in gzip.decompress(original).decode().splitlines():
            validate_schema(json.loads(line), schema)
        self.assertEqual(path.read_bytes(), original)


class ScenarioSchemaTests(unittest.TestCase):
    def schema(self):
        path = ROOT / "measurement/schema/scenario.schema.json"
        if path.exists():
            return json.loads(path.read_text())
        old = json.loads((ROOT / "measurement/schema/trace.schema.json").read_text())
        return old["allOf"][0]["then"]["properties"]["configuration"]

    def validate_entry(self, entry):
        schema = self.schema()
        item = schema.get("properties", {}).get("entries", {}).get("items", schema)
        validate_schema(entry, item, root=schema)

    def test_literal_entry_binds_three_exact_ids_and_revision(self):
        self.validate_entry({"matrix": "scroll.content_first", "native": "native.scroll.content_first",
                             "flutter": "scroll.content_first", "revision": 2})

    def test_omitted_registry_names_are_not_inferred(self):
        for key in ("matrix", "native", "flutter", "revision"):
            entry = {"matrix": "scroll.content_first", "native": "native.scroll.content_first",
                     "flutter": "scroll.content_first", "revision": 2}
            del entry[key]
            with self.subTest(key=key), self.assertRaises(TraceError):
                self.validate_entry(entry)

    def test_unknown_alias_policy_and_invalid_revision_are_rejected(self):
        for change in (lambda e: e.update(infer_aliases=True), lambda e: e.update(revision="2"),
                       lambda e: e.update(revision=0), lambda e: e.update(matrix=None)):
            entry = {"matrix": "scroll.content_first", "native": None, "flutter": None, "revision": 2}
            change(entry)
            with self.subTest(change=change), self.assertRaises(TraceError):
                self.validate_entry(entry)

    def test_map_requires_v2_and_explicit_entries(self):
        for mapping in ({"schema_version": 1, "entries": []}, {"schema_version": 2}):
            with self.subTest(mapping=mapping), self.assertRaises(TraceError):
                validate_schema(mapping, self.schema())


if __name__ == "__main__":
    unittest.main()
