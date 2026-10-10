import importlib.util
import math
import subprocess
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'collect_dynamics.py'
spec = importlib.util.spec_from_file_location('collect_dynamics', SCRIPT)
dynamics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dynamics)


def trial(number=1):
    recipe = dynamics.recipe_grid()[0]
    records = []
    def emit(kind, time, **payload):
        records.append(dict(schema_version=1, type=kind, run_id=f'run-{number}',
                            seq=len(records), t_ns=time, **payload))
    emit('session', 0, native_contract_version=2, implementation='native', evidence_kind='runtime',
         scenario_id=recipe['scenario_id'], os={'version': '26.4.1', 'build': '23E254a'},
         device={'model': 'iPhone18,1', 'refresh_hz': 60, 'scale': 3, 'runtime_kind': 'simulator',
                 'refresh_hz_source': 'UIScreen.maximumFramesPerSecond; measured cadence is per-frame',
                 'logical_size': {'width': 402, 'height': 874}, 'physical_size': {'width': 1206, 'height': 2622}},
         environment={'orientation': 'portrait', 'safe_area': dict(top=62, left=0, bottom=34, right=0),
                      'size_classes': dict(horizontal='compact', vertical='regular'),
                      'status_bar': {'hidden': False}, 'keyboard': {'visible': False, 'frame': dict(x=0, y=0, width=0, height=0)},
                      'system_settings': {'reduce_motion': False, 'voice_over': False, 'content_size_category': 'UICTContentSizeCategoryL'}},
         configuration={'trial': number, 'modal_in_presentation': recipe['dismissal_locked'],
                        'detents': ['fixed320', 'medium', 'large'], 'surface': 'opaque.white', 'grabber': True,
                        'page_sizing': True, 'largest_undimmed': None, 'presentation_style': 'page_sheet',
                        'preferred_content_size': dict(width=320, height=320), 'placement': 'automatic',
                        'edge_attached_in_compact_height': False, 'width_follows_preferred_content_size': False,
                        'scroll_expansion': True},
         provenance={'attempt_id': f'attempt-{number}', 'role': 'training', 'native_source_revision': 'a'*40})
    def event(time, name, data): emit('event', time, name=name, data=data)
    event(1, 'dynamics.session', {'contract_version': 2, 'recipe': recipe, 'fixture_capability_revision': 1,
          'unsupported_fixture_axes': ['nested', 'pager', 'phase_bound_interruptions', 'restricted_detent_pairs']})
    event(2, 'dynamics.input.requested', {'recipe_id': recipe['id']})
    for index, time in enumerate((10_000_000, 25_000_000, 40_000_000)):
        event(time, 'dynamics.frame.observed', {'sample_t_ns': time, 'sheet_position_y': 400,
              'sheet_position_source': 'sampledWindowRect.coherent_common_ancestry',
              'scroll_offset': 0, 'recognizers': [{'relationship': 'sheet/0', 'state': 'possible'}]})
        if index < 2:
            event(time+1, 'dynamics.input.delivered', {'touch_id': 'touch-1',
                  'input_t_ns': time+1, 'position': {'x': 100, 'y': 500-index*10},
                  'phase': 'began' if index == 0 else 'ended',
                  'velocity_y': None if index == 0 else -10 / .015,
                  'velocity_source': 'consecutive_delivered_position_time_finite_difference',
                  'unavailable': {'velocity_y': 'first delivered sample has no preceding sample'} if index == 0 else {}})
    event(40_000_001, 'dynamics.final.observed', {'final_detent': 'medium', 'source': 'public.selectedDetentIdentifier'})
    event(40_000_002, 'dismiss.completed', {})
    records[-1]['terminal'] = True
    return records


class DynamicsContractTests(unittest.TestCase):
    def reject(self, change):
        records = trial()
        change(records)
        with self.assertRaises(ValueError): dynamics.validate_trial(records)

    def test_grid_has_literal_required_axes(self):
        grid = dynamics.recipe_grid()
        self.assertTrue(all(x['contract_version'] == 2 for x in grid))
        self.assertEqual(len({x['id'] for x in grid}), len(grid))
        self.assertEqual({x['overdrag_end'] for x in grid if x['family'] == 'overdrag'}, {'lower', 'upper'})
        self.assertEqual({x['dismissal_locked'] for x in grid}, {True, False})
        self.assertEqual({tuple(x['detent_pair']) for x in grid}, {('fixed320', 'medium'), ('medium', 'large')})
        self.assertEqual({x['release_velocity_y'] for x in grid if x['family'] == 'release'},
                         {-751, -750, -749, -251, -250, -249, 0, 249, 250, 251, 749, 750, 751})
        self.assertEqual({(x['interruption_phase'], x['request_delay_ms']) for x in grid if x['family'] == 'interruption'},
                         {(phase, delay) for phase in ('opening', 'detent', 'dismissal') for delay in (100, 200)})
        self.assertEqual({x['origin'] for x in grid}, {'handle', 'content', 'nested', 'pager'})
        scroll = [x for x in grid if x['family'] == 'scroll']
        self.assertEqual({x['scroll_top_relative_offset'] for x in scroll}, {-1, 0, 1})
        self.assertEqual({x['path'] for x in scroll}, {'vertical', 'diagonal'})
        self.assertEqual({x['second_gesture_after_top'] for x in scroll}, {True, False})
        self.assertEqual(dynamics.REQUEST_THRESHOLDS, [250, 750])

    def test_valid_observed_trial(self):
        self.assertEqual(dynamics.validate_trial(trial())['qualification'], 'delivered-input-contract-only')

    def test_requested_only_is_rejected(self):
        self.reject(lambda r: r.__setitem__(slice(None), [x for x in r if x.get('name') != 'dynamics.input.delivered']))

    def test_missing_delivered_fields_rejected(self):
        for field in ('position', 'input_t_ns', 'velocity_y'):
            with self.subTest(field=field):
                self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.input.delivered' and x['data']['phase'] == 'ended').pop(field))

    def test_nonfinite_delivery_rejected(self):
        for value in (math.nan, math.inf, -math.inf):
            self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.input.delivered' and x['data']['phase'] == 'ended').update(velocity_y=value))

    def test_nonmonotonic_delivery_rejected(self):
        self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.input.delivered' and x['data']['phase'] == 'ended').update(input_t_ns=1))

    def test_gap_exceeding_two_display_frames_rejected(self):
        def gap(records):
            for record in records:
                if record['t_ns'] >= 40_000_000: record['t_ns'] += 20_000_000
                if record.get('name') == 'dynamics.frame.observed' and record['data']['sample_t_ns'] == 40_000_000:
                    record['data']['sample_t_ns'] += 20_000_000
        self.reject(gap)

    def test_missing_observed_outputs_rejected(self):
        for field in ('recognizers', 'sheet_position_y', 'scroll_offset'):
            with self.subTest(field=field):
                self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.frame.observed').pop(field))
        self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.final.observed').pop('final_detent'))

    def test_missing_recognizer_state_rejected(self):
        self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.frame.observed')['recognizers'][0].pop('state'))

    def test_first_sample_velocity_requires_reason(self):
        self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.input.delivered').update(unavailable={}))

    def test_ten_independent_trials_required(self):
        with self.assertRaises(ValueError): dynamics.validate_cohort([trial(i) for i in range(1, 10)])
        with self.assertRaises(ValueError): dynamics.validate_cohort([trial()] * 10)
        self.assertEqual(dynamics.validate_cohort([trial(i) for i in range(1, 11)])['trial_count'], 10)

    def test_metadata_mismatch_rejected(self):
        cohort = [trial(i) for i in range(1, 11)]
        cohort[-1][0]['environment']['orientation'] = 'landscape'
        with self.assertRaises(ValueError): dynamics.validate_cohort(cohort)

    def test_unknown_recipe_rejected(self):
        self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.session')['recipe'].update(id='guessed'))

    def test_interruption_requests_are_not_delivery(self):
        recipe = next(x for x in dynamics.recipe_grid() if x['family'] == 'interruption')
        records = trial()
        records[0]['scenario_id'] = recipe['scenario_id']
        next(x['data'] for x in records if x.get('name') == 'dynamics.session')['recipe'] = recipe
        with self.assertRaises(ValueError): dynamics.validate_trial(records)

    def test_public_native_plumbing_and_strict_request_clock(self):
        source = (SCRIPT.parents[1] / 'NativeSheetHarness' / 'InteractionProbe.swift').read_text()
        for token in ('dynamics.input.delivered', 'dynamics.frame.observed', 'dynamics.final.observed',
                      'touch.timestamp', 'recognizer.state', 'selectedDetentIdentifier',
                      'flags: .strict', 'leeway: .nanoseconds(0)', 'dynamics.landmark.requested'):
            with self.subTest(token=token): self.assertIn(token, source)
        self.assertNotIn('dynamics.landmark.delivered', source)

    def test_frame_gap_boundary_and_missing_terminal(self):
        # Positive clocks: 33,333,334ns is ceil(two periods at 60Hz),
        # and one additional nanosecond must fail the cadence gate itself.
        for extra, accepted in ((18_333_334, True), (18_333_335, False)):
            records = trial()
            for record in records:
                if record['t_ns'] >= 40_000_000: record['t_ns'] += extra
            frames = [x['data'] for x in records if x.get('name') == 'dynamics.frame.observed']
            frames[-1]['sample_t_ns'] = 40_000_000+extra
            if accepted: self.assertEqual(dynamics.validate_trial(records)['qualification'], dynamics.QUALIFICATION)
            else:
                with self.assertRaisesRegex(ValueError, 'frame gap'): dynamics.validate_trial(records)

    def test_coordinate_provenance_must_be_coherent_and_observed(self):
        for value in (None, 'requested', 'presented_content.model_view.bounds_in_model_window', 'direct.presentation.convert'):
            self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.frame.observed').update(sheet_position_source=value))

    def test_velocity_source_and_same_touch_difference_are_required(self):
        for source in (None, 'requested', 'XCTest.velocity'):
            self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.input.delivered' and x['data']['phase'] == 'ended').update(velocity_source=source))
        for velocity in (0, -500, -10/.015 + 1e-6):
            self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.input.delivered' and x['data']['phase'] == 'ended').update(velocity_y=velocity))
        self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.input.delivered' and x['data']['phase'] == 'ended').update(touch_id='different-touch'))

    def test_capability_registry_cannot_be_omitted_or_changed_to_enable_axes(self):
        for key in ('unsupported_fixture_axes', 'fixture_capability_revision'):
            self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.session').pop(key))
        self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.session').update(unsupported_fixture_axes=[]))

    def test_complete_typed_runtime_identity_and_config(self):
        for section, field in [('device', 'runtime_kind'), ('device', 'physical_size'), ('environment', 'safe_area'),
                               ('environment', 'size_classes'), ('environment', 'status_bar'), ('environment', 'keyboard'),
                               ('environment', 'system_settings'), ('configuration', 'detents'), ('configuration', 'placement')]:
            with self.subTest(section=section, field=field): self.reject(lambda r: r[0][section].pop(field))
        for section, field, value in [('os', 'build', 'unresolved'), ('device', 'scale', True),
                                      ('configuration', 'grabber', 1), ('configuration', 'preferred_content_size', None),
                                      ('configuration', 'detents', ['com.apple.UIKit.medium']),
                                      ('configuration', 'trial', True), ('provenance', 'native_source_revision', 'unresolved')]:
            with self.subTest(field=field): self.reject(lambda r: r[0][section].update({field: value}))

    def test_exact_trial_numbers_and_source_role_homogeneity(self):
        for key, value in [('trial', 11), ('trial', True)]:
            runs = [trial(i) for i in range(1, 11)]; runs[-1][0]['configuration'][key] = value
            with self.assertRaises(ValueError): dynamics.validate_cohort(runs)
        runs = [trial(i) for i in range(1, 11)]; runs[-1][0]['provenance']['role'] = 'holdout'
        with self.assertRaises(ValueError): dynamics.validate_cohort(runs)

    def test_native_geometry_uses_existing_common_ancestry_sampler(self):
        source = (SCRIPT.parents[1] / 'NativeSheetHarness' / 'InteractionProbe.swift').read_text()
        self.assertIn('coherentLayerSamples(h.probe.layer)', source)
        self.assertIn('sampledWindowRect(', source)
        self.assertNotIn('layer.convert(', source)

    def test_lifetime_policy_host_and_terminal_hooks(self):
        native = SCRIPT.parents[1] / 'NativeSheetHarness'
        code = '''
do {
  let life = DynamicsObserverLifetime(runID: "run")
  precondition(!life.mustStop(currentRunID: "run", running: true, sheetPresent: true, invalidated: false))
  precondition(life.mustStop(currentRunID: "other", running: true, sheetPresent: true, invalidated: false))
  precondition(life.mustStop(currentRunID: nil, running: true, sheetPresent: true, invalidated: false))
  precondition(life.mustStop(currentRunID: "run", running: false, sheetPresent: true, invalidated: false))
  precondition(life.mustStop(currentRunID: "run", running: true, sheetPresent: false, invalidated: false))
  precondition(life.mustStop(currentRunID: "run", running: true, sheetPresent: true, invalidated: true))
}
print("Dynamics lifetime host assertions PASS: 6")'''
        # Execute the actual Foundation-only implementation, not a copied policy.
        result = subprocess.run(['xcrun', 'swift', '-module-cache-path', '/private/tmp/native-task4a-module-cache',
                                 '-e', (native / 'NativeScenario.swift').read_text()+code], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Dynamics lifetime host assertions PASS: 6', result.stdout)
        source = (native / 'App.swift').read_text()
        # Exact terminal statements must have immediate cleanup before emission.
        for statement in ('t.event("dismiss.completed", terminal: true)', 'trace.event("dismiss.completed", terminal: true)', 'trace?.event("dismiss.interactive_completed")'):
            offset = source.index(statement)
            self.assertIn('invalidateDynamics()', source[max(0, offset-100):offset])
        self.assertIn('guard trace?.invalidated != true else { interaction?.invalidateDynamics(); running = false; return }', source)
        self.assertIn('defer { if trace.invalidated { interaction?.invalidateDynamics() } }', source)
        probe = (native / 'InteractionProbe.swift').read_text()
        cleanup = probe.split('@objc func invalidateDynamics() {', 1)[1].split('\n    }', 1)[0]
        for statement in ('dynamicsActive = false', 'dynamicsLifetime = nil', 'dynamicsLink?.invalidate()',
                          'landmarkTimers.forEach { $0.setEventHandler {}; $0.cancel() }', 'priorTouches.removeAll()'):
            self.assertIn(statement, cleanup)
        self.assertIn('if harness?.trace?.record("event", ["name": name, "data": data]) != true { invalidateDynamics() }', probe)
        for callback in ('private func observeDynamics', '@objc private func sampleDynamics', 'private func dynamicsEvent'):
            body = probe.split(callback, 1)[1].split('\n    }', 1)[0]
            self.assertIn('requireLiveDynamics()', body)
        self.assertIn('name: UIApplication.willTerminateNotification', probe)
        self.reject(lambda r: r[-1].update(terminal=False))

    def test_missing_or_cancelled_final_is_not_a_native_snap(self):
        self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.final.observed').update(source='requested'))
        self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.input.delivered' and x['data']['phase'] == 'ended').update(phase='moved'))

    def test_nonfinite_sheet_scroll_and_touch_coordinates(self):
        for field in ('sheet_position_y', 'scroll_offset'):
            self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.frame.observed').update({field: math.nan}))
        self.reject(lambda r: next(x['data'] for x in r if x.get('name') == 'dynamics.input.delivered')['position'].update(x=math.inf))

    def test_second_recipe_gesture_requires_two_delivered_lifecycles(self):
        recipe = next(x for x in dynamics.recipe_grid() if x.get('second_gesture_after_top'))
        records = trial()
        records[0]['scenario_id'] = recipe['scenario_id']
        next(x['data'] for x in records if x.get('name') == 'dynamics.session')['recipe'] = recipe
        with self.assertRaises(ValueError): dynamics.validate_trial(records)

    def test_nested_pager_observer_fixture_does_not_qualify_as_implemented(self):
        recipe = next(x for x in dynamics.recipe_grid() if x['origin'] == 'nested')
        records = trial()
        records[0]['scenario_id'] = recipe['scenario_id']
        definition = next(x['data'] for x in records if x.get('name') == 'dynamics.session')
        definition['recipe'] = recipe
        definition['unsupported_fixture_axes'] = ['nested', 'pager']
        with self.assertRaises(ValueError): dynamics.validate_trial(records)


if __name__ == '__main__': unittest.main()
