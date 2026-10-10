"""Offline evidence qualification for observed release/snap trajectories.

This gate accepts only a release velocity reconstructed from same-touch
delivered point/timestamp pairs and a public observed final target.  It records
the supplied trajectory grid without deriving UIKit thresholds, detent spacing,
velocity caps, hysteresis, skipping, or spring physics.  The frozen fixture
explicitly does not support phase-bound interruptions, so request landmarks are
not phase evidence and are rejected.
"""
import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('collect_dynamics_for_snap_evidence',
                                               ROOT / 'scripts' / 'collect_dynamics.py')
dynamics = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dynamics)

VELOCITY_SOURCE = 'consecutive_delivered_position_time_finite_difference'
FINAL_TARGET_SOURCE = 'public.selectedDetentIdentifier'
UNSUPPORTED_PHASE_AXIS = 'phase_bound_interruptions'


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def event_records(records, name):
    return [row for row in records if row.get('type') == 'event' and row.get('name') == name]


def recipe_for(records):
    sessions = event_records(records, 'dynamics.session')
    require(len(sessions) == 1 and isinstance(sessions[0].get('data'), dict), 'one dynamics session required')
    recipe = sessions[0]['data'].get('recipe')
    require(isinstance(recipe, dict), 'typed dynamics recipe required')
    return sessions[0]['data'], recipe


def release_samples(records):
    samples = [row.get('data') for row in event_records(records, 'dynamics.input.delivered')]
    require(all(isinstance(row, dict) for row in samples), 'typed delivered samples required')
    ended = [row for row in samples if row.get('phase') == 'ended']
    require(len(ended) == 1, 'one delivered release required')
    release = ended[0]
    prior = [row for row in samples if row.get('touch_id') == release.get('touch_id') and
             row.get('input_t_ns', -1) < release.get('input_t_ns', -1)]
    require(prior, 'same-touch sample before release required')
    previous = prior[-1]
    require(release.get('velocity_source') == VELOCITY_SOURCE, 'release velocity source must be delivered finite difference')
    for sample in (previous, release):
        position = sample.get('position')
        require(isinstance(position, dict) and type(position.get('y')) in (int, float), 'delivered point-space position required')
        require(type(sample.get('input_t_ns')) is int, 'integer delivered timestamp required')
    delta_ns = release['input_t_ns'] - previous['input_t_ns']
    require(delta_ns > 0, 'release timestamp must follow same-touch predecessor')
    expected = (release['position']['y'] - previous['position']['y']) / (delta_ns / 1_000_000_000)
    require(release.get('velocity_y') == expected, 'release velocity/timestamp mismatch')
    return previous, release, expected


def observed_target(records):
    finals = event_records(records, 'dynamics.final.observed')
    require(len(finals) == 1 and isinstance(finals[0].get('data'), dict), 'one observed final target required')
    target = finals[0]['data']
    require(target.get('source') == FINAL_TARGET_SOURCE and target.get('final_detent') in ('fixed320', 'medium', 'large'),
            'observed final target required')
    return target['final_detent']


def validate_trial(records):
    definition, recipe = recipe_for(records)
    if recipe.get('family') == 'interruption':
        unsupported = definition.get('unsupported_fixture_axes')
        require(isinstance(unsupported, list) and UNSUPPORTED_PHASE_AXIS not in unsupported,
                'phase-bound interruptions unsupported by current fixture')
        raise ValueError('phase-bound interruptions require observed boundaries, delivered/actual retarget time, and bracketed position/velocity')
    require(recipe.get('family') == 'release', 'release recipe required')
    previous, release, velocity = release_samples(records)
    target = observed_target(records)
    qualified = dynamics.validate_trial(records)
    return dict(qualification='release-snap-observation-contract', recipe_id=recipe['id'],
                release_position_y=release['position']['y'],
                release_velocity_y_points_per_second=velocity, observed_target=target,
                position_velocity_grid={'position_y': release['position']['y'],
                                        'velocity_y_points_per_second': velocity},
                detent_spacing={'status': 'unavailable', 'reason': 'No observed detent-frame spacing in this payload.'},
                threshold_holdout={'status': 'required', 'reason': 'No threshold fitting or holdout acceptance from this fixture.'},
                delivered_samples=qualified['delivered_samples'],
                continuity={'release_predecessor_position_y': previous['position']['y'],
                            'release_position_y': release['position']['y'],
                            'release_velocity_y_points_per_second': velocity,
                            'status': 'observed_bracket_only'},
                limitations=['No native cap, hysteresis, skip, spring, or target-selection rule inferred.',
                             'Final detent is observed, not a physical settling claim.'])


def validate_cohort(trials):
    require(len(trials) == 10, 'ten independent release trials required')
    sessions = [records[0] for records in trials]
    roles = [session.get('provenance', {}).get('role') for session in sessions]
    require(all(role == 'training' for role in roles), 'training/holdout leakage: release qualification requires training-only cohort')
    dynamics.validate_cohort(trials)
    results = [validate_trial(records) for records in trials]
    run_ids = [session.get('run_id') for session in sessions]
    attempt_ids = [session.get('provenance', {}).get('attempt_id') for session in sessions]
    require(len(set(run_ids)) == len(run_ids) and len(set(attempt_ids)) == len(attempt_ids), 'duplicate run/attempt evidence')
    keys = ('recipe_id', 'observed_target', 'position_velocity_grid')
    require(all(all(result[key] == results[0][key] for key in keys) for result in results), 'mixed release-snap cohort conditions')
    return dict(status='accepted_synthetic_release_snap_contract', proof_layer='synthetic_fixture_contract',
                trial_count=10, recipe_id=results[0]['recipe_id'], observed_target=results[0]['observed_target'],
                release_velocity_y_points_per_second=results[0]['release_velocity_y_points_per_second'],
                position_velocity_grid=results[0]['position_velocity_grid'],
                detent_spacing=results[0]['detent_spacing'], threshold_holdout=results[0]['threshold_holdout'],
                continuity=results[0]['continuity'],
                limitations=results[0]['limitations'] + ['Phase-bound interruption qualification remains unsupported.'])
