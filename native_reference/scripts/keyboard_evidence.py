import math


REQUIRED_CONDITIONS = (
    'os_build', 'device', 'orientation', 'scale', 'safe_area', 'keyboard',
    'accessibility', 'configuration', 'scenario_revision', 'gesture_recipe',
)


def _number(value, *, minimum=0):
    return type(value) in (int, float) and math.isfinite(value) and value >= minimum


def _nonempty_string(value):
    return isinstance(value, str) and bool(value.strip())


def _rect(value):
    return (isinstance(value, dict) and set(value) == {'x', 'y', 'width', 'height'} and
            _number(value['x'], minimum=-math.inf) and _number(value['y'], minimum=-math.inf) and
            _number(value['width']) and _number(value['height']))


def _canonical_conditions(conditions):
    if not isinstance(conditions, dict) or set(conditions) != set(REQUIRED_CONDITIONS):
        return False
    device = conditions['device']
    safe_area = conditions['safe_area']
    keyboard = conditions['keyboard']
    accessibility = conditions['accessibility']
    configuration = conditions['configuration']
    recipe = conditions['gesture_recipe']
    return (
        _nonempty_string(conditions['os_build']) and
        isinstance(device, dict) and set(device) == {'model', 'runtime_kind'} and
        _nonempty_string(device['model']) and device['runtime_kind'] in ('simulator', 'virtual_device', 'physical_device') and
        conditions['orientation'] in ('portrait', 'landscape', 'portrait_upside_down') and
        _number(conditions['scale']) and conditions['scale'] > 0 and
        isinstance(safe_area, dict) and set(safe_area) == {'top', 'left', 'bottom', 'right'} and
        all(_number(safe_area[edge]) for edge in safe_area) and
        isinstance(keyboard, dict) and set(keyboard) == {'visible', 'frame'} and
        type(keyboard['visible']) is bool and _rect(keyboard['frame']) and
        isinstance(accessibility, dict) and set(accessibility) == {'reduce_motion', 'voice_over', 'content_size_category'} and
        type(accessibility['reduce_motion']) is bool and type(accessibility['voice_over']) is bool and
        _nonempty_string(accessibility['content_size_category']) and
        isinstance(configuration, dict) and set(configuration) == {'presentation_style', 'detents'} and
        configuration['presentation_style'] in ('page_sheet', 'form_sheet') and
        isinstance(configuration['detents'], list) and bool(configuration['detents']) and
        all(_nonempty_string(detent) for detent in configuration['detents']) and
        type(conditions['scenario_revision']) is int and conditions['scenario_revision'] >= 1 and
        isinstance(recipe, dict) and set(recipe) == {'id', 'revision'} and
        _nonempty_string(recipe['id']) and type(recipe['revision']) is int and recipe['revision'] >= 1
    )


def _observation_is_runtime_notification(observation):
    if not isinstance(observation, dict):
        return False
    if observation.get('source') != 'public_notification':
        return False
    frame = observation.get('frame')
    if not _rect(frame):
        return False
    if not _number(observation.get('duration')) or not _number(observation.get('timestamp')):
        return False
    if type(observation.get('curve')) is not int or observation['curve'] < 0:
        return False
    if observation.get('focus') not in ('focused', 'unfocused'):
        return False
    if not _number(observation.get('inset')):
        return False
    if observation.get('inset_basis') != 'viewport_intersection_no_safe_area_addition':
        return False
    if observation.get('interactive_phase') != 'unavailable':
        return False
    presence = observation.get('keyboard_presence')
    if presence == 'hardware':
        return False
    if observation['inset'] > 0 and presence != 'software':
        return False
    if observation['inset'] == 0 and presence != 'unavailable':
        return False
    return True


def _valid_trial(row, expected_conditions, run_ids, expected_trial):
    if not isinstance(row, dict) or row.get('evidence_kind') != 'runtime' or row.get('implementation') != 'native':
        return False
    if row.get('complete') is not True:
        return False
    run_id = row.get('run_id')
    if (not _nonempty_string(run_id) or run_id in run_ids or
            type(row.get('trial')) is not int or row['trial'] != expected_trial):
        return False
    conditions = row.get('conditions')
    if not _canonical_conditions(conditions):
        return False
    selected = {key: conditions[key] for key in REQUIRED_CONDITIONS}
    if expected_conditions is not None and selected != expected_conditions:
        return False
    observations = row.get('observations')
    if not isinstance(observations, list) or not observations or not all(_observation_is_runtime_notification(o) for o in observations):
        return False
    timestamps = [o['timestamp'] for o in observations]
    if timestamps != sorted(timestamps) or len(timestamps) != len(set(timestamps)):
        return False
    run_ids.add(run_id)
    return selected


def validate_cohort(rows):
    """Accept only ten or more independent, fully matched native runtime trials.

    Fixture data can exercise this validator, but cannot promote a native
    capability: runtime provenance and actual public-notification observations
    remain required at collection time.
    """
    if not isinstance(rows, list) or len(rows) < 10:
        return {'accepted': False, 'reason': 'at_least_ten_trials_required'}
    run_ids = set()
    expected_conditions = None
    for expected_trial, row in enumerate(rows, start=1):
        conditions = _valid_trial(row, expected_conditions, run_ids, expected_trial)
        if conditions is False:
            return {'accepted': False, 'reason': 'invalid_or_mixed_trial'}
        expected_conditions = conditions
    return {'accepted': True, 'trials': len(rows), 'conditions': expected_conditions}
