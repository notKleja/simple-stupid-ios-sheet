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


dynamics = load('collect_dynamics_for_snap', ROOT / 'scripts' / 'collect_dynamics.py')
snap = load('snap_interruption_evidence', ROOT / 'scripts' / 'snap_interruption_evidence.py')


def release_trial(number=1, role='training'):
    recipe = next(row for row in dynamics.recipe_grid()
                  if row['family'] == 'release' and row['release_velocity_y'] == -250)
    records = []

    def emit(kind, time, **payload):
        records.append(dict(schema_version=1, type=kind, run_id=f'snap-run-{number}',
                            seq=len(records), t_ns=time, **payload))

    emit('session', 0, native_contract_version=2, implementation='native', evidence_kind='runtime',
         scenario_id=recipe['scenario_id'], os={'version': '26.4.1', 'build': '23E254a'},
         device={'model': 'iPhone18,1', 'refresh_hz': 60, 'scale': 3, 'runtime_kind': 'simulator',
                 'refresh_hz_source': 'synthetic fixture',
                 'logical_size': {'width': 402, 'height': 874},
                 'physical_size': {'width': 1206, 'height': 2622}},
         environment={'orientation': 'portrait', 'safe_area': {'top': 62, 'left': 0, 'bottom': 34, 'right': 0},
                      'size_classes': {'horizontal': 'compact', 'vertical': 'regular'},
                      'status_bar': {'hidden': False},
                      'keyboard': {'visible': False, 'frame': {'x': 0, 'y': 0, 'width': 0, 'height': 0}},
                      'system_settings': {'reduce_motion': False, 'voice_over': False,
                                          'content_size_category': 'UICTContentSizeCategoryL'}},
         configuration={'trial': number, 'modal_in_presentation': False,
                        'detents': ['fixed320', 'medium', 'large'], 'surface': 'opaque.white', 'grabber': True,
                        'page_sizing': True, 'largest_undimmed': None, 'presentation_style': 'page_sheet',
                        'preferred_content_size': {'width': 320, 'height': 320}, 'placement': 'automatic',
                        'edge_attached_in_compact_height': False, 'width_follows_preferred_content_size': False,
                        'scroll_expansion': True},
         provenance={'attempt_id': f'snap-attempt-{number}', 'role': role, 'native_source_revision': 'c' * 40})

    def event(time, name, data):
        emit('event', time, name=name, data=data)

    event(1, 'dynamics.session', {'contract_version': 2, 'recipe': recipe, 'fixture_capability_revision': 1,
                                   'unsupported_fixture_axes': ['nested', 'pager', 'phase_bound_interruptions',
                                                                'restricted_detent_pairs']})
    event(2, 'dynamics.input.requested', {'recipe_id': recipe['id']})
    positions = (500, 490)
    touches = ((10_000_001, 500, 'began', None),
               (25_000_001, 490, 'moved', -10 / .015))
    for index, time in enumerate((10_000_000, 25_000_000)):
        event(time, 'dynamics.frame.observed', {'sample_t_ns': time, 'sheet_position_y': positions[index],
              'sheet_position_source': 'sampledWindowRect.coherent_common_ancestry', 'scroll_offset': 0,
              'recognizers': [{'relationship': 'sheet/0', 'state': 'changed'}]})
        input_time, y, phase, velocity = touches[index]
        event(input_time, 'dynamics.input.delivered', {
            'touch_id': 'touch-1', 'input_t_ns': input_time, 'position': {'x': 100, 'y': y}, 'phase': phase,
            'velocity_y': velocity, 'velocity_source': 'consecutive_delivered_position_time_finite_difference',
            'unavailable': {'velocity_y': 'first delivered sample'} if velocity is None else {}})
    event(40_000_001, 'dynamics.input.delivered', {'touch_id': 'touch-1', 'input_t_ns': 40_000_001,
          'position': {'x': 100, 'y': 480}, 'phase': 'ended', 'velocity_y': -10 / .015,
          'velocity_source': 'consecutive_delivered_position_time_finite_difference', 'unavailable': {}})
    event(40_000_002, 'dynamics.frame.observed', {'sample_t_ns': 40_000_002, 'sheet_position_y': 480,
          'sheet_position_source': 'sampledWindowRect.coherent_common_ancestry', 'scroll_offset': 0,
          'recognizers': [{'relationship': 'sheet/0', 'state': 'changed'}]})
    event(40_000_003, 'dynamics.final.observed', {'final_detent': 'medium',
                                                    'source': 'public.selectedDetentIdentifier'})
    event(40_000_004, 'dismiss.completed', {})
    records[-1]['terminal'] = True
    return records


class SnapInterruptionEvidenceTests(unittest.TestCase):
    def cohort(self):
        return [release_trial(number) for number in range(1, 11)]

    def delivered(self, records):
        return [row['data'] for row in records if row.get('name') == 'dynamics.input.delivered']

    def test_accepts_literal_release_trajectory_with_observed_snap_target(self):
        result = snap.validate_cohort(self.cohort())
        self.assertEqual(result['status'], 'accepted_synthetic_release_snap_contract')
        self.assertEqual(result['proof_layer'], 'synthetic_fixture_contract')
        self.assertEqual(result['observed_target'], 'medium')
        self.assertEqual(result['release_velocity_y_points_per_second'], -10 / .015)
        self.assertNotIn('threshold', result)

    def test_rejects_wrong_velocity_source_and_timestamp_release_mismatch(self):
        records = release_trial()
        self.delivered(records)[-1]['velocity_source'] = 'requested.recipe.velocity'
        with self.assertRaisesRegex(ValueError, 'velocity source'):
            snap.validate_trial(records)
        records = release_trial()
        self.delivered(records)[-1]['input_t_ns'] += 1
        with self.assertRaisesRegex(ValueError, 'timestamp'):
            snap.validate_trial(records)

    def test_rejects_unobserved_final_target(self):
        records = release_trial()
        final = next(row['data'] for row in records if row.get('name') == 'dynamics.final.observed')
        final['final_detent'] = None
        with self.assertRaisesRegex(ValueError, 'observed final target'):
            snap.validate_trial(records)

    def test_requested_only_interruption_phase_is_rejected(self):
        records = release_trial()
        recipe = next(row for row in dynamics.recipe_grid() if row['family'] == 'interruption')
        records[0]['scenario_id'] = recipe['scenario_id']
        session = next(row['data'] for row in records if row.get('name') == 'dynamics.session')
        session['recipe'] = recipe
        records.insert(-2, dict(schema_version=1, type='event', run_id=records[0]['run_id'], seq=900,
                                t_ns=40_000_001, name='dynamics.landmark.requested',
                                data={'delay_ms': recipe['request_delay_ms'], 'phase': recipe['interruption_phase'],
                                      'anchor_t_ns': 0, 'deadline_t_ns': recipe['request_delay_ms'] * 1_000_000}))
        with self.assertRaisesRegex(ValueError, 'phase-bound interruptions unsupported'):
            snap.validate_trial(records)

    def test_rejects_duplicate_short_cohort_and_holdout_leakage(self):
        with self.assertRaisesRegex(ValueError, 'ten independent'):
            snap.validate_cohort(self.cohort()[:-1])
        duplicate = self.cohort()
        duplicate[-1] = copy.deepcopy(duplicate[0])
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            snap.validate_cohort(duplicate)
        leakage = self.cohort()
        leakage[-1][0]['provenance']['role'] = 'holdout'
        with self.assertRaisesRegex(ValueError, 'training/holdout'):
            snap.validate_cohort(leakage)


if __name__ == '__main__':
    unittest.main()
