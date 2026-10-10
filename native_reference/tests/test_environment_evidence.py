import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from environment_evidence import validate_environment_fixture


def record(index):
    return {
        'schema_version': 1,
        'evidence_kind': 'fixture',
        'observation_id': f'literal-{index}',
        'identity': {
            'os_build': 'iOS 27.0 (24A123)',
            'device_model': 'iPhone18,3',
            'runtime_kind': 'simulator',
            'orientation': 'landscape',
            'horizontal_size_class': 'compact',
            'vertical_size_class': 'compact',
            'safe_area': {'top': 0, 'left': 0, 'bottom': 21, 'right': 0},
        },
        'configured': {
            'presentation_style': 'page',
            'preferred_content_size': {'width': 0, 'height': 0},
            'edge_attached_in_compact_height': False,
            'width_follows_preferred_content_size': True,
            'source_anchor': {'x': 12, 'y': 24, 'width': 48, 'height': 32},
        },
        'resolved': {
            'presentation_style': 'page',
            'preferred_content_size': {'width': 0, 'height': 0},
            'source_anchor': {'x': 12, 'y': 24, 'width': 48, 'height': 32},
            'placement': {'value': 'bottom', 'availability': 'observed_supported'},
            'source': 'public_runtime_observation',
        },
    }


class EnvironmentEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.rows = [record(index) for index in range(10)]

    def reject(self):
        self.assertFalse(validate_environment_fixture(self.rows)['qualified'])

    def test_literal_same_environment_fixture_is_scope_qualified_only(self):
        result = validate_environment_fixture(self.rows)
        self.assertTrue(result['qualified'])
        self.assertEqual(result['proof_layer'], 'literal_fixture_contract_only')
        self.assertFalse(result['native_capability_accepted'])

    def test_json_serialized_swift_shaped_record_reaches_exact_scope_gate(self):
        self.rows = [json.loads(json.dumps(record(index))) for index in range(10)]
        self.assertTrue(validate_environment_fixture(self.rows)['qualified'])

    def test_observed_adaptive_page_to_form_stays_distinct_and_qualifies(self):
        for row in self.rows:
            row['resolved']['presentation_style'] = 'form'
        result = validate_environment_fixture(self.rows)
        self.assertTrue(result['qualified'])
        self.assertEqual(result['qualified_scope']['configured']['presentation_style'], 'page')
        self.assertEqual(result['qualified_scope']['resolved']['presentation_style'], 'form')

    def test_mixed_observed_adaptive_style_is_not_one_scope(self):
        self.rows[-1]['resolved']['presentation_style'] = 'form'
        self.reject()

    def test_identity_axes_cannot_mix_phone_tablet_orientation_or_size_classes(self):
        for key, value in [('os_build', 'iOS 26.4 (23E999)'), ('device_model', 'iPad16,3'),
                           ('runtime_kind', 'physical_device'), ('orientation', 'portrait'),
                           ('horizontal_size_class', 'regular'), ('vertical_size_class', 'regular')]:
            with self.subTest(key=key):
                self.setUp(); self.rows[-1]['identity'][key] = value; self.reject()

    def test_safe_area_missing_differs_from_observed_zero(self):
        self.assertTrue(validate_environment_fixture(self.rows)['qualified'])
        for key in ('top', 'left', 'bottom', 'right'):
            with self.subTest(key=key):
                self.setUp(); del self.rows[-1]['identity']['safe_area'][key]; self.reject()
        self.setUp(); self.rows[-1]['identity']['safe_area']['bottom'] = 22; self.reject()

    def test_page_form_and_incomplete_resolution_cannot_qualify(self):
        self.rows[-1]['configured']['presentation_style'] = 'form'; self.reject()
        self.setUp(); self.rows[-1]['resolved']['presentation_style'] = None; self.reject()

    def test_configured_values_cannot_self_certify_as_resolved_observation(self):
        self.rows[-1]['resolved']['source'] = 'configured_value'; self.reject()
        self.setUp(); self.rows[-1]['resolved'] = None; self.reject()

    def test_invalid_anchor_and_unknown_or_unsupported_placement_reject(self):
        for field, value in [('x', float('nan')), ('width', -1)]:
            with self.subTest(field=field):
                self.setUp(); self.rows[-1]['resolved']['source_anchor'][field] = value; self.reject()
        for placement in [
            {'value': 'unavailable', 'availability': 'unavailable'},
            {'value': 'sideways', 'availability': 'observed_supported'},
            {'value': 'bottom', 'availability': 'unsupported'},
        ]:
            with self.subTest(placement=placement):
                self.setUp(); self.rows[-1]['resolved']['placement'] = placement; self.reject()


if __name__ == '__main__':
    unittest.main()
