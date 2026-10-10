import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from accessibility_evidence import validate_cohort


def record(trial):
    return {
        'schema_version': 1, 'evidence_kind': 'fixture', 'observation_id': f'accessibility-{trial}',
        'run_id': f'native-accessibility-{trial}', 'trial': trial, 'layer_id': 'sheet.layer.1',
        'conditions': {
            'os_build': 'iOS 27.0 (24A123)', 'device_model': 'iPhone18,3', 'runtime_kind': 'simulator',
            'orientation': 'portrait', 'configuration': {'modal_in_presentation': False},
            'accessibility': {
                'reduce_motion': True, 'reduce_motion_source': 'public_system_setting',
                'content_size_category': 'UICTContentSizeCategoryAccessibilityL', 'content_size_source': 'public_trait_collection',
                'locale_identifier': 'ar-SA', 'layout_direction': 'rtl', 'locale_source': 'public_locale',
            },
        },
        'escape': {'requested': True, 'requested_gesture_id': f'escape-{trial}', 'callback': {'callback': 'accessibilityPerformEscape', 'layer_id': 'sheet.layer.1', 'gesture_id': f'escape-{trial}', 'outcome': 'dismissed'}, 'delivered': True, 'delivered_gesture_id': f'escape-{trial}'},
        'dismissal': {'locked': False, 'callback': 'presentationControllerDidDismiss', 'callback_result': True, 'layer_id': 'sheet.layer.1', 'observation_id': f'accessibility-{trial}', 'gesture_id': f'escape-{trial}', 'did_dismiss': True},
        'focus': {'callback': 'accessibility_focus_callback', 'layer_id': 'sheet.layer.1', 'observation_id': f'accessibility-{trial}', 'gesture_id': f'escape-{trial}', 'before_id': 'sheet.field', 'restored_id': 'presenter.button', 'restored': True, 'outcome': 'restored'},
        'semantic': {'barrier_dismiss_label': 'رفض', 'label_locale': 'ar-SA', 'source': 'public_localized_string'},
    }


class AccessibilityEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.rows = [record(index) for index in range(1, 11)]

    def reject(self, text):
        result = validate_cohort(self.rows)
        self.assertFalse(result['qualified'])
        self.assertIn(text, result['reason'])

    def test_ten_matching_literal_fixtures_qualify_only_the_contract_scope(self):
        result = validate_cohort(self.rows)
        self.assertTrue(result['qualified'])
        self.assertEqual(result['proof_layer'], 'literal_fixture_contract_only')
        self.assertFalse(result['native_capability_accepted'])

    def test_json_serialized_swift_shaped_canonical_record_reaches_gate(self):
        self.rows = [json.loads(json.dumps(record(index))) for index in range(1, 11)]
        self.assertTrue(validate_cohort(self.rows)['qualified'])

    def test_rejects_unknown_provenance_instead_of_relabeling_it_fixture(self):
        self.rows[-1]['evidence_kind'] = 'unavailable'
        self.reject('invalid_provenance')

    def test_rejects_launch_only_or_missing_actual_accessibility_settings(self):
        self.rows[-1]['conditions']['accessibility']['reduce_motion_source'] = 'launch_argument'
        self.reject('reduce_motion')
        self.setUp(); del self.rows[-1]['conditions']['accessibility']['content_size_category']
        self.reject('accessibility_conditions')

    def test_rejects_requested_only_escape_unrelated_callbacks_and_stale_layer(self):
        self.rows[-1]['escape']['callback']['outcome'] = 'requested'
        self.rows[-1]['escape']['delivered'] = False
        self.reject('escape_not_delivered')
        self.setUp(); self.rows[-1]['focus']['callback'] = 'unrelated_notification'
        self.reject('focus_callback')
        self.setUp(); self.rows[-1]['escape']['callback']['layer_id'] = 'stale.layer'
        self.reject('layer_binding')

    def test_rejects_stale_delivered_gesture_and_wrong_callback_provenance(self):
        self.rows[-1]['escape']['delivered_gesture_id'] = 'stale-gesture'
        self.reject('gesture_binding')
        self.setUp(); self.rows[-1]['dismissal']['callback'] = 'presentationControllerShouldDismiss'
        self.reject('dismissal_callback')

    def test_rejects_locked_dismissal_falsely_marked_success(self):
        self.rows[-1]['conditions']['configuration']['modal_in_presentation'] = True
        self.rows[-1]['dismissal']['locked'] = True
        self.reject('dismissal_callback')

    def test_valid_locked_cohort_requires_preserved_focus_not_fabricated_restoration(self):
        for row in self.rows:
            row['conditions']['configuration']['modal_in_presentation'] = True
            row['escape'].update({'delivered': False})
            row['escape']['callback']['outcome'] = 'blocked'
            row['dismissal'].update({'locked': True, 'callback': 'presentationControllerShouldDismiss', 'callback_result': False, 'did_dismiss': False})
            row['focus'].update({'before_id': 'sheet.field', 'restored_id': 'sheet.field', 'restored': False, 'outcome': 'preserved'})
        self.assertTrue(validate_cohort(self.rows)['qualified'])
        self.rows[-1]['focus'].update({'restored': True, 'outcome': 'restored'})
        self.reject('locked_focus')
        self.setUp()
        for row in self.rows:
            row['conditions']['configuration']['modal_in_presentation'] = True
            row['escape'].update({'delivered': False})
            row['escape']['callback']['outcome'] = 'blocked'
            row['dismissal'].update({'locked': True, 'callback': 'presentationControllerShouldDismiss', 'callback_result': False, 'did_dismiss': False})
            row['focus'].update({'before_id': 'sheet.field', 'restored_id': 'sheet.field', 'restored': False, 'outcome': 'preserved'})
        self.rows[-1]['dismissal']['did_dismiss'] = True
        self.reject('locked_dismissal')

    def test_rejects_true_locked_should_dismiss_result_even_without_dismissal(self):
        for row in self.rows:
            row['conditions']['configuration']['modal_in_presentation'] = True
            row['escape'].update({'delivered': False})
            row['escape']['callback']['outcome'] = 'blocked'
            row['dismissal'].update({'locked': True, 'callback': 'presentationControllerShouldDismiss', 'callback_result': False, 'did_dismiss': False})
            row['focus'].update({'before_id': 'sheet.field', 'restored_id': 'sheet.field', 'restored': False, 'outcome': 'preserved'})
        self.rows[-1]['dismissal']['callback_result'] = True
        self.reject('locked_dismissal')

    def test_rejects_absent_locale_and_mismatched_or_short_cohorts(self):
        del self.rows[-1]['conditions']['accessibility']['locale_identifier']
        self.reject('accessibility_conditions')
        self.setUp(); self.rows[-1]['conditions']['accessibility']['layout_direction'] = 'ltr'
        self.reject('mixed_conditions')
        self.setUp(); self.rows.pop()
        self.reject('at_least_ten_trials_required')

    def test_rejects_duplicate_runs_and_nonlocalized_semantics(self):
        self.rows[-1]['run_id'] = self.rows[0]['run_id']
        self.reject('duplicate')
        self.setUp(); self.rows[-1]['semantic']['label_locale'] = 'en-US'
        self.reject('semantic_locale')


if __name__ == '__main__':
    unittest.main()
