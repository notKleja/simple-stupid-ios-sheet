import copy
import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


dynamics = load('collect_dynamics_for_overdrag', ROOT / 'scripts' / 'collect_dynamics.py')
overdrag = load('overdrag_evidence', ROOT / 'scripts' / 'overdrag_evidence.py')


def synthetic_trial(number=1, side='upper', locked=False):
    recipe = next(x for x in dynamics.recipe_grid()
                  if x['family'] == 'overdrag' and x['overdrag_end'] == side
                  and x['dismissal_locked'] is locked)
    records = []
    def emit(kind, time, **payload):
        records.append(dict(schema_version=1, type=kind, run_id=f'overdrag-run-{number}',
                            seq=len(records), t_ns=time, **payload))
    emit('session', 0, native_contract_version=2, implementation='native', evidence_kind='runtime',
         scenario_id=recipe['scenario_id'], os={'version': '26.4.1', 'build': '23E254a'},
         device={'model': 'iPhone18,1', 'refresh_hz': 60, 'scale': 3, 'runtime_kind': 'simulator',
                 'refresh_hz_source': 'synthetic fixture',
                 'logical_size': {'width': 402, 'height': 874}, 'physical_size': {'width': 1206, 'height': 2622}},
         environment={'orientation': 'portrait', 'safe_area': {'top': 62, 'left': 0, 'bottom': 34, 'right': 0},
                      'size_classes': {'horizontal': 'compact', 'vertical': 'regular'},
                      'status_bar': {'hidden': False}, 'keyboard': {'visible': False, 'frame': {'x': 0, 'y': 0, 'width': 0, 'height': 0}},
                      'system_settings': {'reduce_motion': False, 'voice_over': False, 'content_size_category': 'UICTContentSizeCategoryL'}},
         configuration={'trial': number, 'modal_in_presentation': locked,
                        'detents': ['fixed320', 'medium', 'large'], 'surface': 'opaque.white', 'grabber': True,
                        'page_sizing': True, 'largest_undimmed': None, 'presentation_style': 'page_sheet',
                        'preferred_content_size': {'width': 320, 'height': 320}, 'placement': 'automatic',
                        'edge_attached_in_compact_height': False, 'width_follows_preferred_content_size': False,
                        'scroll_expansion': True},
         provenance={'attempt_id': f'overdrag-attempt-{number}', 'role': 'training', 'native_source_revision': 'b'*40})
    def event(time, name, data): emit('event', time, name=name, data=data)
    event(1, 'dynamics.session', {'contract_version': 2, 'recipe': recipe, 'fixture_capability_revision': 1,
          'unsupported_fixture_axes': ['nested', 'pager', 'phase_bound_interruptions', 'restricted_detent_pairs']})
    event(2, 'dynamics.input.requested', {'recipe_id': recipe['id']})
    positions = (300, 290, 300) if side == 'upper' else (600, 610, 600)
    for index, time in enumerate((10_000_000, 25_000_000, 40_000_000)):
        event(time, 'dynamics.frame.observed', {'sample_t_ns': time, 'sheet_position_y': positions[index],
              'sheet_position_source': 'sampledWindowRect.coherent_common_ancestry', 'scroll_offset': 0,
              'recognizers': [{'relationship': 'sheet/0', 'state': 'changed'}]})
        if index < 2:
            event(time + 1, 'dynamics.input.delivered', {'touch_id': 'touch-1', 'input_t_ns': time + 1,
                  'position': {'x': 100, 'y': 500 - index * 10}, 'phase': 'began' if index == 0 else 'ended',
                  'velocity_y': None if index == 0 else -10 / .015,
                  'velocity_source': 'consecutive_delivered_position_time_finite_difference',
                  'unavailable': {'velocity_y': 'first delivered sample'} if index == 0 else {}})
    event(40_000_001, 'dynamics.overdrag.observed', {
        'side': side, 'coordinate_convention': 'increasing_sheet_position_y_moves_toward_lower_detent',
        'coordinate_source': 'sampledWindowRect.coherent_common_ancestry',
        'actual_bounds_y': {'upper': 300, 'lower': 600},
        'actual_bounds_source': 'public.resolvedDetentFrame.sampledWindowRect',
        'actual_bounds_identity': {'upper': 'fixed320', 'lower': 'large'},
        'observed_extrema_y': {'minimum': 290 if side == 'upper' else 600,
                                'maximum': 300 if side == 'upper' else 610},
        'lock_state': locked, 'touch_lifecycle': 'delivered_began_to_ended',
        'evidence_provenance': 'synthetic_fixture'})
    event(40_000_002, 'dynamics.final.observed', {'final_detent': 'medium', 'source': 'public.selectedDetentIdentifier'})
    event(40_000_003, 'dismiss.completed', {})
    records[-1]['terminal'] = True
    return records


class OverdragEvidenceTests(unittest.TestCase):
    def cohort(self, side='upper', locked=False):
        return [synthetic_trial(i, side, locked) for i in range(1, 11)]

    def observed(self, records):
        return next(x['data'] for x in records if x.get('name') == 'dynamics.overdrag.observed')

    def test_accepts_ten_matching_synthetic_trials_without_physics_claim(self):
        result = overdrag.validate_cohort(self.cohort())
        self.assertEqual(result['status'], 'accepted_synthetic_contract')
        self.assertEqual(result['proof_layer'], 'synthetic_fixture_contract')
        self.assertNotIn('resistance', result)

    def test_rejects_requested_only_excursion(self):
        records = synthetic_trial()
        records[:] = [x for x in records if x.get('name') != 'dynamics.overdrag.observed']
        with self.assertRaisesRegex(ValueError, 'observed overdrag'):
            overdrag.validate_trial(records)

    def test_rejects_absent_actual_bound_and_wrong_side(self):
        records = synthetic_trial()
        self.observed(records)['actual_bounds_y'].pop('upper')
        with self.assertRaisesRegex(ValueError, 'actual upper bound'):
            overdrag.validate_trial(records)
        records = synthetic_trial()
        for record in records:
            if record.get('name') == 'dynamics.frame.observed': record['data']['sheet_position_y'] = 300
        self.observed(records)['observed_extrema_y'] = {'minimum': 300, 'maximum': 300}
        with self.assertRaisesRegex(ValueError, 'upper excursion'):
            overdrag.validate_trial(records)

    def test_rejects_extrema_that_do_not_reconcile_to_observed_frames(self):
        records = synthetic_trial()
        self.observed(records)['observed_extrema_y']['minimum'] = 100
        with self.assertRaisesRegex(ValueError, 'observed frame extrema'):
            overdrag.validate_trial(records)

    def test_rejects_requested_only_actual_bound_source(self):
        records = synthetic_trial()
        self.observed(records)['actual_bounds_source'] = 'dynamics.input.requested.recipe.endpoints'
        with self.assertRaisesRegex(ValueError, 'actual-bound source'):
            overdrag.validate_trial(records)

    def test_rejects_duplicate_configuration_trial_and_mixed_runtime_metadata(self):
        duplicate_trial = self.cohort()
        duplicate_trial[-1][0]['configuration']['trial'] = 1
        with self.assertRaisesRegex(ValueError, 'duplicate/missing trial ID'):
            overdrag.validate_cohort(duplicate_trial)
        mixed_device = self.cohort()
        mixed_device[-1][0]['device']['model'] = 'iPhone18,2'
        with self.assertRaisesRegex(ValueError, 'mixed cohort conditions'):
            overdrag.validate_cohort(mixed_device)

    def test_rejects_lock_mismatch_and_incoherent_coordinate_convention(self):
        for key, value, reason in (
            ('lock_state', True, 'lock mismatch'),
            ('coordinate_convention', 'unknown', 'coordinate convention'),
            ('coordinate_source', 'requested', 'coordinate provenance'),
        ):
            with self.subTest(key=key):
                records = synthetic_trial()
                self.observed(records)[key] = value
                with self.assertRaisesRegex(ValueError, reason): overdrag.validate_trial(records)

    def test_rejects_mixed_os_configuration_duplicate_and_short_cohorts(self):
        short = self.cohort()[:-1]
        with self.assertRaisesRegex(ValueError, 'ten independent'): overdrag.validate_cohort(short)
        duplicate = self.cohort(); duplicate[-1] = copy.deepcopy(duplicate[0])
        with self.assertRaisesRegex(ValueError, 'duplicate'): overdrag.validate_cohort(duplicate)
        mixed = self.cohort(); mixed[-1][0]['os']['build'] = 'different'
        with self.assertRaisesRegex(ValueError, 'mixed cohort'): overdrag.validate_cohort(mixed)
        config = self.cohort(); config[-1][0]['configuration']['grabber'] = False
        with self.assertRaises(ValueError): overdrag.validate_cohort(config)

    def test_rejects_two_detent_requested_grid_against_three_detent_fixture(self):
        records = synthetic_trial()
        definition = next(x['data'] for x in records if x.get('name') == 'dynamics.session')
        definition['recipe']['overdrag_grid_detents'] = ['medium', 'large']
        with self.assertRaisesRegex(ValueError, 'two-detent requested grid'):
            overdrag.validate_trial(records)


if __name__ == '__main__':
    unittest.main()
