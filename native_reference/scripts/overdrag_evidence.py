"""Offline acceptance gate for observed overdrag evidence.

This validates delivered observations; it does not fit or claim a UIKit
resistance/physics model.  Synthetic fixtures remain synthetic proof only.
"""
import argparse
import copy
import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
_DYNAMICS_SPEC = importlib.util.spec_from_file_location('collect_dynamics', ROOT / 'scripts' / 'collect_dynamics.py')
dynamics = importlib.util.module_from_spec(_DYNAMICS_SPEC)
_DYNAMICS_SPEC.loader.exec_module(dynamics)

COORDINATE_CONVENTION = 'increasing_sheet_position_y_moves_toward_lower_detent'
COORDINATE_SOURCE = dynamics.COORDINATE_SOURCE
EFFECTIVE_DETENTS = ['fixed320', 'medium', 'large']
ACTUAL_BOUNDS_SOURCE = 'public.resolvedDetentFrame.sampledWindowRect'


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def finite_number(value):
    return type(value) in (int, float) and value == value and value not in (float('inf'), float('-inf'))


def event_data(records, name):
    matches = [record['data'] for record in records if record.get('type') == 'event' and record.get('name') == name]
    require(len(matches) == 1, 'exactly one observed overdrag event required')
    return matches[0]


def recipe_data(records):
    matches = [record['data'] for record in records if record.get('type') == 'event' and record.get('name') == 'dynamics.session']
    require(len(matches) == 1 and isinstance(matches[0].get('recipe'), dict), 'missing dynamics recipe')
    return matches[0]['recipe']


def validate_trial(records):
    recipe = recipe_data(records)
    require(recipe.get('family') == 'overdrag', 'overdrag recipe required')
    # A requested two-detent grid cannot be silently substituted for the
    # fixture's known effective three-detent set.  (recipe.detent_pair is a
    # legacy request axis, not a selected evidence grid.)
    selected = recipe.get('overdrag_grid_detents')
    require(selected is None or selected == EFFECTIVE_DETENTS, 'two-detent requested grid conflicts with effective fixture detents')
    result = dynamics.validate_trial(records)
    session = records[0]
    config = session['configuration']
    require(config.get('detents') == EFFECTIVE_DETENTS, 'actual effective detent-set required')

    observed = event_data(records, 'dynamics.overdrag.observed')
    side = recipe.get('overdrag_end')
    require(side in ('upper', 'lower') and observed.get('side') == side, 'observed overdrag side mismatch')
    require(observed.get('coordinate_convention') == COORDINATE_CONVENTION, 'incoherent coordinate convention')
    require(observed.get('coordinate_source') == COORDINATE_SOURCE, 'unaccepted coordinate provenance')
    require(observed.get('touch_lifecycle') == 'delivered_began_to_ended', 'delivered touch lifecycle required')
    require(observed.get('lock_state') is recipe.get('dismissal_locked'), 'lock mismatch')
    bounds, extrema = observed.get('actual_bounds_y'), observed.get('observed_extrema_y')
    require(observed.get('actual_bounds_source') == ACTUAL_BOUNDS_SOURCE,
            'canonical actual-bound source required; requested endpoints are not observed bounds')
    bound_identity = observed.get('actual_bounds_identity')
    require(isinstance(bound_identity, dict) and bound_identity.get('upper') in config['detents'] and
            bound_identity.get('lower') in config['detents'] and
            bound_identity['upper'] != bound_identity['lower'], 'actual-bound identity must use distinct effective detents')
    require(isinstance(bounds, dict) and finite_number(bounds.get('upper')), 'actual upper bound required')
    require(isinstance(bounds, dict) and finite_number(bounds.get('lower')), 'actual lower bound required')
    require(bounds['upper'] < bounds['lower'], 'incoherent actual bound ordering')
    require(isinstance(extrema, dict) and finite_number(extrema.get('minimum')) and finite_number(extrema.get('maximum')),
            'observed extrema required')
    require(extrema['minimum'] <= extrema['maximum'], 'incoherent observed extrema')
    frame_positions = [record['data']['sheet_position_y'] for record in records
                       if record.get('type') == 'event' and record.get('name') == 'dynamics.frame.observed']
    require(extrema['minimum'] == min(frame_positions) and extrema['maximum'] == max(frame_positions),
            'observed extrema do not reconcile to observed frame extrema')
    if side == 'upper':
        require(extrema['minimum'] < bounds['upper'], 'upper excursion was not observed beyond actual bound')
    else:
        require(extrema['maximum'] > bounds['lower'], 'lower excursion was not observed beyond actual bound')
    provenance = observed.get('evidence_provenance')
    require(provenance in ('synthetic_fixture', 'delivered_runtime'), 'overdrag evidence provenance required')
    return dict(**result, side=side, locked=recipe['dismissal_locked'], os=session['os'],
                effective_detents=config['detents'], provenance=provenance,
                bounds_y=copy.deepcopy(bounds), extrema_y=copy.deepcopy(extrema))


def validate_cohort(trials):
    require(len(trials) == 10, 'ten independent matching trials required')
    # Preserve the corrected collector's exact trial-set and full runtime
    # identity checks before adding overdrag-specific cohort conditions.
    dynamics.validate_cohort(trials)
    results = [validate_trial(records) for records in trials]
    keys = ('recipe_id', 'side', 'locked', 'os', 'effective_detents', 'provenance')
    require(all(all(result[key] == results[0][key] for key in keys) for result in results), 'mixed cohort conditions')
    run_ids = [records[0].get('run_id') for records in trials]
    attempts = [records[0].get('provenance', {}).get('attempt_id') for records in trials]
    require(len(set(run_ids)) == len(run_ids) and len(set(attempts)) == len(attempts), 'duplicate trial/run/attempt evidence')
    synthetic = results[0]['provenance'] == 'synthetic_fixture'
    return dict(status='accepted_synthetic_contract' if synthetic else 'accepted_delivered_observation_contract',
                proof_layer='synthetic_fixture_contract' if synthetic else 'delivered_runtime_observation_contract',
                trial_count=10, observed_summary={key: results[0][key] for key in keys if key != 'recipe_id'},
                limitations=['No fitted resistance formula.', 'No native physics or parity acceptance.',
                             'Unsupported fixture scope remains unresolved.'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('traces', type=Path, nargs='+')
    args = parser.parse_args()
    trials = [[json.loads(line) for line in path.read_text().splitlines() if line.strip()] for path in args.traces]
    print(json.dumps(validate_cohort(trials), indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
