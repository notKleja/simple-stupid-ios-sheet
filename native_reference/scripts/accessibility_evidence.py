"""Fail-closed offline gate for callback-bound accessibility observations.

This validates literal rows and future matching cohorts. It never turns a
fixture into native runtime evidence or infers a dismissal from a request.
"""
import math


def _text(value):
    return isinstance(value, str) and bool(value.strip())


def _bool(value):
    return type(value) is bool


def _accessibility(value):
    required = {'reduce_motion', 'reduce_motion_source', 'content_size_category',
                'content_size_source', 'locale_identifier', 'layout_direction', 'locale_source'}
    if not isinstance(value, dict) or set(value) != required:
        return False
    return (_bool(value['reduce_motion']) and value['reduce_motion_source'] == 'public_system_setting' and
            _text(value['content_size_category']) and value['content_size_source'] == 'public_trait_collection' and
            _text(value['locale_identifier']) and value['layout_direction'] in ('ltr', 'rtl') and
            value['locale_source'] == 'public_locale')


def _conditions(value):
    required = {'os_build', 'device_model', 'runtime_kind', 'orientation', 'configuration', 'accessibility'}
    if not isinstance(value, dict) or set(value) != required or not _accessibility(value['accessibility']):
        return False
    return (_text(value['os_build']) and _text(value['device_model']) and
            value['runtime_kind'] in ('simulator', 'virtual_device', 'physical_device') and
            value['orientation'] in ('portrait', 'portrait_upside_down', 'landscape') and
            isinstance(value['configuration'], dict) and set(value['configuration']) == {'modal_in_presentation'} and
            _bool(value['configuration']['modal_in_presentation']))


def _row_reason(row):
    required = {'schema_version', 'evidence_kind', 'observation_id', 'run_id', 'trial', 'layer_id',
                'conditions', 'escape', 'dismissal', 'focus', 'semantic'}
    if not isinstance(row, dict) or set(row) != required or row.get('schema_version') != 1:
        return 'invalid_record'
    if row['evidence_kind'] not in ('fixture', 'runtime_observation'):
        return 'invalid_provenance'
    if not _text(row['observation_id']) or not _text(row['run_id']) or not _text(row['layer_id']) or type(row['trial']) is not int or row['trial'] < 1:
        return 'invalid_identity'
    if not _conditions(row['conditions']):
        candidate_accessibility = row['conditions'].get('accessibility') if isinstance(row['conditions'], dict) else None
        if isinstance(candidate_accessibility, dict) and candidate_accessibility.get('reduce_motion_source') != 'public_system_setting':
            return 'reduce_motion_source'
        return 'accessibility_conditions'
    access = row['conditions']['accessibility']
    if access['reduce_motion_source'] != 'public_system_setting':
        return 'reduce_motion_source'
    escape = row['escape']
    expected_escape = {'requested', 'requested_gesture_id', 'callback', 'delivered', 'delivered_gesture_id'}
    if not isinstance(escape, dict) or set(escape) != expected_escape or escape['requested'] is not True or not isinstance(escape['callback'], dict):
        return 'escape_callback'
    callback = escape['callback']
    if set(callback) != {'callback', 'layer_id', 'gesture_id', 'outcome'} or callback['callback'] != 'accessibilityPerformEscape' or not _text(callback['gesture_id']):
        return 'escape_callback'
    if callback['layer_id'] != row['layer_id']:
        return 'layer_binding'
    if not _text(escape['requested_gesture_id']) or not _text(escape['delivered_gesture_id']) or callback['gesture_id'] != escape['requested_gesture_id'] or callback['gesture_id'] != escape['delivered_gesture_id']:
        return 'gesture_binding'
    locked = row['conditions']['configuration']['modal_in_presentation']
    dismissal = row['dismissal']
    if not isinstance(dismissal, dict) or set(dismissal) != {'locked', 'callback', 'callback_result', 'layer_id', 'observation_id', 'gesture_id', 'did_dismiss'} or dismissal['locked'] is not locked or not _bool(dismissal['callback_result']):
        return 'dismissal_callback'
    if dismissal['layer_id'] != row['layer_id']:
        return 'layer_binding'
    if dismissal['observation_id'] != row['observation_id'] or dismissal['gesture_id'] != escape['requested_gesture_id']:
        return 'gesture_binding'
    if locked and dismissal['callback'] != 'presentationControllerShouldDismiss':
        return 'dismissal_callback'
    if locked and (escape['delivered'] or callback['outcome'] != 'blocked' or dismissal['callback_result'] is not False or dismissal['did_dismiss']):
        return 'locked_dismissal'
    if not locked and dismissal['callback'] != 'presentationControllerDidDismiss':
        return 'dismissal_callback'
    if not locked and (escape['delivered'] is not True or callback['outcome'] != 'dismissed' or dismissal['callback_result'] is not True or dismissal['did_dismiss'] is not True):
        return 'escape_not_delivered'
    focus = row['focus']
    if not isinstance(focus, dict) or set(focus) != {'callback', 'layer_id', 'observation_id', 'gesture_id', 'before_id', 'restored_id', 'restored', 'outcome'} or focus['callback'] != 'accessibility_focus_callback':
        return 'focus_callback'
    if focus['layer_id'] != row['layer_id']:
        return 'layer_binding'
    if focus['observation_id'] != row['observation_id'] or focus['gesture_id'] != escape['requested_gesture_id']:
        return 'gesture_binding'
    if not _text(focus['before_id']) or not _text(focus['restored_id']):
        return 'focus_restoration'
    if locked:
        if focus['outcome'] != 'preserved' or focus['restored'] is not False or focus['before_id'] != focus['restored_id']:
            return 'locked_focus'
    elif focus['outcome'] != 'restored' or focus['restored'] is not True or focus['before_id'] == focus['restored_id']:
        return 'focus_restoration'
    semantic = row['semantic']
    if not isinstance(semantic, dict) or set(semantic) != {'barrier_dismiss_label', 'label_locale', 'source'} or not _text(semantic['barrier_dismiss_label']) or semantic['source'] != 'public_localized_string' or semantic['label_locale'] != access['locale_identifier']:
        return 'semantic_locale'
    return None


def validate_cohort(rows):
    """Qualify ten independent, matching rows without capability promotion."""
    if not isinstance(rows, list) or len(rows) < 10:
        return {'qualified': False, 'reason': 'at_least_ten_trials_required'}
    for row in rows:
        reason = _row_reason(row)
        if reason:
            return {'qualified': False, 'reason': reason}
    if len({row['run_id'] for row in rows}) != len(rows) or len({row['observation_id'] for row in rows}) != len(rows):
        return {'qualified': False, 'reason': 'duplicate_run_or_observation'}
    if [row['trial'] for row in rows] != list(range(1, len(rows) + 1)):
        return {'qualified': False, 'reason': 'trial_sequence'}
    first = rows[0]
    conditions = first['conditions']
    if any(row['conditions'] != conditions for row in rows):
        return {'qualified': False, 'reason': 'mixed_conditions'}
    if len({row['evidence_kind'] for row in rows}) != 1:
        return {'qualified': False, 'reason': 'mixed_evidence_kind'}
    proof_layer = 'literal_fixture_contract_only' if first['evidence_kind'] == 'fixture' else 'runtime_cohort_observation'
    return {'qualified': True, 'trials': len(rows), 'proof_layer': proof_layer,
            'native_capability_accepted': False, 'qualified_scope': conditions}
