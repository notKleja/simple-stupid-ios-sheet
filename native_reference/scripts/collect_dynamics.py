"""Offline dynamics-v2 collector. No launch, injection, or physics acceptance.

Thresholds, detent pairs, origin, and offsets below are requested experiment
definitions, NOT measured UIKit thresholds/spacings/ownership. Qualification
proves only complete delivered-input observations. It does not prove recipes
were achieved (including release velocity, overdrag or interruption phase).
"""
import argparse
import gzip
import hashlib
import json
import math
import re
from pathlib import Path

REQUEST_THRESHOLDS = [250, 750]
QUALIFICATION = 'delivered-input-contract-only'
VELOCITY_SOURCE = 'consecutive_delivered_position_time_finite_difference'
COORDINATE_SOURCE = 'sampledWindowRect.coherent_common_ancestry'
FIXTURE_CAPABILITY_REVISION = 1
# Frozen observer-fixture capability, not a caller-declared allow-list.
UNSUPPORTED_FIXTURE_AXES = ['nested', 'pager', 'phase_bound_interruptions', 'restricted_detent_pairs']


def recipe_grid():
    result = []
    def add(family, pair=('medium', 'large'), locked=False, origin='handle', path='vertical', **axes):
        # Explicit registry; no substring inference or unknown-ID fallthrough.
        scenario = ('native.dynamics.scroll.locked' if locked else 'native.dynamics.scroll') if origin != 'handle' else (
            'native.dynamics.handle.locked' if locked else 'native.dynamics.handle')
        result.append(dict(contract_version=2, recipe_revision=1,
                           id=f'dynamics-v2-{len(result)+1:03d}', scenario_id=scenario,
                           family=family, detent_pair=list(pair), dismissal_locked=locked,
                           origin=origin, path=path, **axes))
    pairs = [('fixed320', 'medium'), ('medium', 'large')]
    for pair in pairs:
        for locked in (False, True):
            for end in ('lower', 'upper'):
                add('overdrag', pair, locked, overdrag_end=end)
        for velocity in (-751, -750, -749, -251, -250, -249, 0, 249, 250, 251, 749, 750, 751):
            add('release', pair, release_velocity_y=velocity, request_thresholds=REQUEST_THRESHOLDS[:])
    for phase in ('opening', 'detent', 'dismissal'):
        for delay in (100, 200):
            add('interruption', interruption_phase=phase, request_delay_ms=delay)
    for offset in (-1, 0, 1):
        for origin in ('content', 'nested', 'pager'):
            for path in ('vertical', 'diagonal'):
                for second in (False, True):
                    add('scroll', origin=origin, path=path, scroll_top_relative_offset=offset,
                        second_gesture_after_top=second)
    return result


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def integer(value):
    return type(value) is int and value >= 0


def observed_string(value):
    return isinstance(value, str) and bool(value.strip()) and not any(
        marker in value.lower() for marker in ('unresolved', 'unknown', 'unavailable', 'uncommitted'))


def object_field(parent, key):
    value = parent.get(key)
    require(isinstance(value, dict), 'missing typed object: '+key)
    return value


def validate_runtime_identity(session):
    os = object_field(session, 'os')
    require(observed_string(os.get('version')) and re.fullmatch(r'\d+(?:\.\d+)+', os['version']) is not None,
            'observed numeric OS version required')
    require(observed_string(os.get('build')), 'observed OS build required')
    device = object_field(session, 'device')
    require(observed_string(device.get('model')), 'observed device model required')
    require(device.get('runtime_kind') in ('simulator', 'virtual_device', 'physical_device'), 'runtime provenance required')
    for key in ('logical_size', 'physical_size'):
        size = object_field(device, key)
        require(all(finite(size.get(axis)) and size[axis] > 0 for axis in ('width', 'height')), 'positive typed device dimensions required')
    require(all(finite(device.get(k)) and device[k] > 0 for k in ('scale', 'refresh_hz')), 'positive typed scale/refresh required')
    require(observed_string(device.get('refresh_hz_source')), 'refresh capability provenance required')
    environment = object_field(session, 'environment')
    require(environment.get('orientation') in ('portrait', 'landscape', 'portrait_upside_down'), 'observed orientation required')
    safe = object_field(environment, 'safe_area')
    require(all(finite(safe.get(k)) and safe[k] >= 0 for k in ('top', 'left', 'bottom', 'right')), 'complete typed safe area required')
    classes = object_field(environment, 'size_classes')
    require(all(classes.get(k) in ('compact', 'regular', 'unspecified') for k in ('horizontal', 'vertical')), 'complete typed size classes required')
    status = object_field(environment, 'status_bar')
    require(type(status.get('hidden')) is bool, 'observed status bar required')
    keyboard = object_field(environment, 'keyboard')
    frame = object_field(keyboard, 'frame')
    require(type(keyboard.get('visible')) is bool and all(finite(frame.get(k)) for k in ('x', 'y', 'width', 'height'))
            and frame['width'] >= 0 and frame['height'] >= 0, 'complete typed keyboard metadata required')
    settings = object_field(environment, 'system_settings')
    require(all(type(settings.get(k)) is bool for k in ('reduce_motion', 'voice_over')) and
            observed_string(settings.get('content_size_category')), 'complete typed accessibility metadata required')
    config = object_field(session, 'configuration')
    require(type(config.get('trial')) is int and 1 <= config['trial'] <= 10, 'integer trial1..10 required')
    detents = config.get('detents')
    require(isinstance(detents, list) and detents == ['fixed320', 'medium', 'large'], 'canonical effective observer-fixture detents required')
    for key in ('grabber', 'page_sizing', 'modal_in_presentation', 'edge_attached_in_compact_height',
                'width_follows_preferred_content_size', 'scroll_expansion'):
        require(type(config.get(key)) is bool, 'missing typed behavior flag: '+key)
    require(config.get('surface') == 'opaque.white', 'opaque calibration surface required')
    require('largest_undimmed' in config and config['largest_undimmed'] is None, 'modal observer-fixture undimmed policy required')
    require(config.get('presentation_style') == 'page_sheet' and config.get('placement') == 'automatic', 'observer-fixture style/placement mismatch')
    size = object_field(config, 'preferred_content_size')
    require(all(finite(size.get(k)) and size[k] == 320 for k in ('width', 'height')), 'typed effective preferred content size required')
    require(config['grabber'] and config['page_sizing'] and config['scroll_expansion'] and
            not config['edge_attached_in_compact_height'] and not config['width_follows_preferred_content_size'], 'observer-fixture policy mismatch')
    provenance = object_field(session, 'provenance')
    require(observed_string(provenance.get('attempt_id')), 'observed attempt ID required')
    require(provenance.get('role') in ('training', 'holdout'), 'typed source role required')
    require(isinstance(provenance.get('native_source_revision'), str) and
            re.fullmatch(r'[0-9a-f]{40}', provenance['native_source_revision']) is not None, 'immutable source revision required')


def validate_trial(records):
    require(bool(records) and records[0].get('type') == 'session', 'missing leading session')
    session = records[0]
    require(sum(r.get('type') == 'session' for r in records) == 1, 'exactly one session required')
    require(session.get('native_contract_version') == 2 and session.get('implementation') == 'native'
            and session.get('evidence_kind') == 'runtime', 'canonical native v2 runtime required')
    validate_runtime_identity(session)
    run = session.get('run_id')
    require(isinstance(run, str) and bool(run), 'missing run ID')
    previous_seq = previous_time = -1
    for record in records:
        require(record.get('schema_version') == 1 and record.get('run_id') == run, 'mixed envelope/run')
        require(record.get('type') in ('session', 'event', 'frame'), 'unknown canonical record type')
        seq, time = record.get('seq'), record.get('t_ns')
        require(integer(seq) and seq > previous_seq and integer(time) and time >= previous_time, 'invalid sequence/clock')
        previous_seq, previous_time = seq, time
    require(records[-1].get('name') == 'dismiss.completed' and records[-1].get('terminal') is True,
            'missing successful canonical terminal')
    require(not any(r.get('name') == 'run.error' for r in records), 'failed run')
    events = {}
    for record in records:
        if record.get('type') == 'event':
            require(isinstance(record.get('data'), dict), 'invalid event data')
            events.setdefault(record.get('name'), []).append(record)
    definitions = events.get('dynamics.session', [])
    require(len(definitions) == 1, 'one dynamics definition required')
    definition = definitions[0]['data']
    recipe = definition.get('recipe')
    require(definition.get('contract_version') == 2 and recipe in recipe_grid(), 'unknown or altered recipe')
    require(type(definition.get('fixture_capability_revision')) is int and
            definition['fixture_capability_revision'] == FIXTURE_CAPABILITY_REVISION and
            definition.get('unsupported_fixture_axes') == UNSUPPORTED_FIXTURE_AXES, 'missing/altered frozen fixture capability registry')
    require(recipe['origin'] not in UNSUPPORTED_FIXTURE_AXES, 'requested origin has no native fixture')
    require(not (recipe['family'] == 'interruption' and 'phase_bound_interruptions' in UNSUPPORTED_FIXTURE_AXES),
            'phase-bound interruption fixture unresolved')
    require(session.get('scenario_id') == recipe['scenario_id'], 'scenario does not match recipe')
    configuration = session.get('configuration', {})
    require(configuration.get('modal_in_presentation') is recipe['dismissal_locked'], 'lock condition mismatch')
    require(bool(events.get('dynamics.input.requested')), 'missing requested-input provenance')
    delivered = events.get('dynamics.input.delivered', [])
    require(len(delivered) >= 2, 'requested input is not delivered input')
    last_time = -1
    touches = {}
    prior_samples = {}
    deliveries = []
    for record in delivered:
        sample = record['data']
        time, point, touch = sample.get('input_t_ns'), sample.get('position', {}), sample.get('touch_id')
        require(integer(time) and time > last_time and time <= record['t_ns'], 'nonmonotonic/invalid delivered time')
        require(isinstance(point, dict) and finite(point.get('x')) and finite(point.get('y')), 'missing finite delivered position')
        require(isinstance(touch, str) and bool(touch), 'missing delivered touch identity')
        phase = sample.get('phase')
        velocity = sample.get('velocity_y')
        require(sample.get('velocity_source') == VELOCITY_SOURCE, 'unobserved/requested velocity source')
        require('velocity_y' in sample, 'missing delivered velocity field')
        if touch not in touches:
            require(phase == 'began' and velocity is None and bool(sample.get('unavailable', {}).get('velocity_y')),
                    'first sample must declare unavailable finite-difference velocity')
        else:
            require(touches[touch] not in ('ended', 'cancelled') and phase in ('moved', 'ended', 'cancelled'), 'invalid touch lifecycle')
            require(finite(velocity), 'missing/nonfinite consecutive delivered velocity')
            prior = prior_samples[touch]
            expected = (point['y']-prior['position']['y']) / ((time-prior['input_t_ns'])/1e9)
            require(velocity == expected, 'velocity differs from exact same-touch serialized position/time difference')
        touches[touch] = phase
        prior_samples[touch] = sample
        last_time = time
        deliveries.append(time)
    require(all(phase in ('ended', 'cancelled') for phase in touches.values()), 'incomplete delivered touch lifecycle')
    require(not recipe.get('second_gesture_after_top') or len(touches) >= 2, 'second gesture was requested but not delivered')
    frames = events.get('dynamics.frame.observed', [])
    require(len(frames) >= 2, 'missing observed frames')
    hz = session.get('device', {}).get('refresh_hz')
    require(finite(hz) and hz > 0, 'unknown display cadence')
    limit = math.ceil(2_000_000_000 / hz)
    frame_times = []
    for record in frames:
        sample = record['data']
        time = sample.get('sample_t_ns')
        require(integer(time) and time <= record['t_ns'] and (not frame_times or time > frame_times[-1]), 'invalid observed frame clock')
        require(not frame_times or time-frame_times[-1] <= limit, 'frame gap exceeds two display frames')
        require(finite(sample.get('sheet_position_y')), 'unobserved sheet position')
        require(sample.get('sheet_position_source') == COORDINATE_SOURCE, 'unaccepted coordinate provenance')
        require(finite(sample.get('scroll_offset')), 'unobserved scroll offset')
        recognizers = sample.get('recognizers')
        require(isinstance(recognizers, list) and bool(recognizers), 'missing public recognizer observations')
        for recognizer in recognizers:
            require(isinstance(recognizer, dict) and bool(recognizer.get('relationship')) and recognizer.get('state') in
                    ('possible', 'began', 'changed', 'ended', 'cancelled', 'failed'), 'missing public recognizer state')
        frame_times.append(time)
    require(frame_times[0] <= deliveries[0] and frame_times[-1] >= deliveries[-1], 'frames do not bracket delivered input')
    finals = events.get('dynamics.final.observed', [])
    require(len(finals) == 1, 'one observed final detent required')
    final = finals[0]['data']
    require(final.get('final_detent') in ('fixed320', 'medium', 'large') and
            final.get('source') == 'public.selectedDetentIdentifier', 'missing observed final detent')
    require(finals[0]['t_ns'] >= frame_times[-1] and finals[0]['t_ns']-frame_times[-1] <= limit, 'final outside complete observed window')
    if recipe['family'] == 'interruption':
        landmarks = events.get('dynamics.landmark.requested', [])
        require(any(x['data'].get('delay_ms') == recipe['request_delay_ms'] and
                    x['data'].get('phase') == recipe['interruption_phase'] and
                    integer(x['data'].get('anchor_t_ns')) and integer(x['data'].get('deadline_t_ns')) and
                    x['data']['deadline_t_ns'] == x['data']['anchor_t_ns']+recipe['request_delay_ms']*1_000_000
                    and x['t_ns'] >= x['data']['deadline_t_ns'] for x in landmarks), 'missing shared-clock requested landmark')
    return dict(qualification=QUALIFICATION, recipe_id=recipe['id'], delivered_samples=len(delivered), frames=len(frames))


def validate_cohort(trials):
    require(len(trials) == 10, 'exactly ten independent trials required')
    results = [validate_trial(records) for records in trials]
    sessions = [records[0] for records in trials]
    for field, values in [('run', [s['run_id'] for s in sessions]),
                          ('trial', [s.get('configuration', {}).get('trial') for s in sessions]),
                          ('attempt', [s.get('provenance', {}).get('attempt_id') for s in sessions])]:
        require(all(x is not None and x != '' for x in values) and len(set(values)) == 10, f'duplicate/missing {field} ID')
    require({s['configuration']['trial'] for s in sessions} == set(range(1, 11)), 'exact integer trial set1..10 required')
    def identity(session):
        config = dict(session['configuration'])
        config.pop('trial')
        require(all(isinstance(session.get(k), dict) and bool(session[k]) for k in ('os', 'device', 'environment')), 'missing runtime metadata')
        return [session['scenario_id'], session['os'], session['device'], session['environment'], config,
                session['provenance']['native_source_revision'], session['provenance']['role']]
    identities = [identity(s) for s in sessions]
    require(all(x == identities[0] for x in identities) and len({r['recipe_id'] for r in results}) == 1, 'mixed cohort conditions')
    return dict(qualification=QUALIFICATION, trial_count=10, recipe_id=results[0]['recipe_id'], trials=results,
                limitations=['No achieved-recipe, native physics, ownership, handoff or parity acceptance.'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('traces', type=Path, nargs='*')
    parser.add_argument('--recipes', action='store_true')
    args = parser.parse_args()
    if args.recipes:
        require(not args.traces, 'recipe listing does not collect traces')
        print(json.dumps(recipe_grid(), indent=2))
        return
    trials, artifacts = [], []
    for path in args.traces:
        raw = path.read_bytes()
        data = gzip.decompress(raw) if path.suffix == '.gz' else raw
        trials.append([json.loads(line) for line in data.splitlines() if line.strip()])
        artifacts.append(dict(path=str(path.resolve()), sha256=hashlib.sha256(raw).hexdigest()))
    summary = validate_cohort(trials)
    summary['artifacts'] = artifacts
    print(json.dumps(summary, indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
