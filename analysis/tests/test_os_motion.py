"""Literal install-object fixtures; these are not measured OS parameters."""
import base64
import copy
import gzip
import hashlib
import json
import math
from pathlib import Path
import struct
import tempfile
import unittest
import uuid

from analysis.os_motion import EvidenceError, load_animation_objects
from analysis import os_motion


class OSMotionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.binary_uuid = '0D94422F-FE7C-302E-B896-3BC5873C0CFC'
        self.binary = self.root / 'UIKitCore'
        self.binary.write_bytes(struct.pack('<8I', 0xFEEDFACF, 0x100000C, 2, 6, 2, 96, 0, 0)
                                + struct.pack('<2I', 0x1B, 24) + uuid.UUID(self.binary_uuid).bytes
                                + struct.pack('<2I16s4Q4I', 0x19, 72, b'__TEXT', 0x100000000, 0x1000, 0, 0x1000, 5, 5, 0, 0))
        self.source = self.root / 'AnimationProbe.swift'; self.source.write_text('literal source fixture\n')
        self.rows = []
        point = {'encoding': '{CGPoint=dd}', 'bytes_base64': base64.b64encode(struct.pack('<2d', 1, 2)).decode()}
        layer_state = {'position': [1, 2], 'bounds': [0, 0, 10, 20], 'anchor_point': [.5, .5], 'anchor_point_z': 0,
                       'transform': [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
                       'sublayer_transform': [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
                       'opacity': 1, 'z_position': 0, 'geometry_flipped': False}
        animation = {'animation_class': 'CASpringAnimation', 'key_path': 'position', 'from_value': point,
                     'to_value': point, 'by_value': None, 'current_value': None, 'model_value': point,
                     'timing_function': {'name': 'custom', 'control_points': [[0, 0], [.1, .2], [.3, .4], [1, 1]]},
                     'spring': {'mass': 2, 'stiffness': 300, 'damping': 40, 'initial_velocity': 3, 'settling_duration': .75, 'allows_overdamping': False},
                     'duration': .75, 'begin_time': 0, 'time_offset': .1, 'speed': .5, 'repeat_count': 2,
                     'repeat_duration': 4, 'autoreverses': True, 'fill_mode': 'both', 'additive': True,
                     'cumulative': True, 'removed_on_completion': False, 'children': None, 'keyframe': None, 'transition': None}
        for trial in range(1, 11):
            run = f'run-{trial}'
            self.rows.append({'type': 'session', 'run_id': run, 'seq': 0, 't_ns': trial * 1000000000,
                              'capture_mode': 'animation_objects', 'scenario_id': 'native.geometry.smoke',
                              'os': {'version': '26.6.2', 'build': '23G90'},
                              'device': {'model': 'iPhone99,11', 'runtime_kind': 'virtual_device'},
                              'configuration': {'trial': trial}})
            for seq, phase in enumerate(['presentation', 'fixed320_to_medium', 'medium_to_large', 'large_to_medium', 'dismissal'], 1):
                self.rows.append({'schema_version': 1, 'type': 'animation_install', 'run_id': run, 'trial': trial,
                                  'seq': seq, 't_ns': trial * 1000000000 + seq, 'phase': phase,
                                  'transaction_time': trial + seq / 1000000000,
                                  'transaction': {'duration': .25, 'disable_actions': False, 'timing_function': None},
                                  'layer': {'id': 'layer.1', 'class': 'CALayer', 'address': '0x1234', 'parent_id': None,
                                            'model_state': copy.deepcopy(layer_state), 'presentation_state': None, 'ancestry': []},
                                  'key': 'position', 'animation': copy.deepcopy(animation),
                                  'backtrace': [{'address': '0x1100', 'image': '/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore',
                                                 'image_uuid': self.binary_uuid, 'image_base': '0x1000', 'image_offset': 256,
                                                 'symbol': '__UISheetAnimateWithCompletion', 'symbol_address': '0x1000'}]})
            self.rows.append({'type': 'event', 'run_id': run, 'seq': 6, 't_ns': trial * 1000000000 + 6,
                              'name': 'dismiss.completed', 'terminal': True})
        self.manifest = {'schema_version': 1, 'evidence_kind': 'runtime_animation_install',
                         'capture_mode': 'animation_objects', 'scenario_id': 'native.geometry.smoke',
                         'os': {'version': '26.6.2', 'build': '23G90'},
                         'device': {'model': 'iPhone99,11', 'runtime_kind': 'virtual_device'},
                         'trial_count': 10, 'record_count': 50, 'records_file': 'animation-objects.jsonl.gz',
                         'native_source_revision': 'a' * 40,
                         'source_files': [{'path': str(self.source), 'sha256': hashlib.sha256(self.source.read_bytes()).hexdigest()}],
                         'images': [{'path': str(self.binary), 'runtime_path': '/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore',
                                     'uuid': self.binary_uuid, 'sha256': hashlib.sha256(self.binary.read_bytes()).hexdigest()}]}
        self.install_rows = [row for row in self.rows if row['type'] == 'animation_install']
        self.configuration = {'detents': ['fixed320', 'medium', 'large'], 'edge_attached_in_compact_height': False,
                              'grabber': True, 'largest_undimmed': None, 'modal_in_presentation': False, 'page_sizing': True,
                              'placement': 'automatic', 'preferred_content_size': {'width': 320, 'height': 320},
                              'presentation_style': 'page_sheet', 'scroll_expansion': True, 'surface': 'opaque.white',
                              'width_follows_preferred_content_size': False}
        self.geometry = {'model': 'iPhone99,11', 'runtime_kind': 'virtual_device', 'logical_size': {'width': 430, 'height': 932},
                         'physical_size': {'width': 1290, 'height': 2796}, 'scale': 3, 'refresh_hz': 60,
                         'refresh_hz_source': 'UIScreen.maximumFramesPerSecond; measured cadence is per-frame'}
        self.environment = {'orientation': 'portrait', 'safe_area': {'top': 59, 'left': 0, 'right': 0, 'bottom': 34},
                            'size_classes': {'horizontal': 'compact', 'vertical': 'regular'}, 'status_bar': {'hidden': False},
                            'keyboard': {'visible': False, 'frame': {'x': 0, 'y': 0, 'width': 0, 'height': 0}},
                            'system_settings': {'reduce_motion': False, 'voice_over': False, 'content_size_category': 'UICTContentSizeCategoryL'}}
        self.resolved = {'fixed': 320, 'medium': 469.84000000000003, 'large': 839, 'maximum': 839}
        self.manifest.update({'configuration': self.configuration, 'device_geometry': self.geometry,
                              'environment': self.environment, 'resolved_detents': self.resolved,
                              'capture_request': {'attempt_id': 'literal-attempt', 'capture_mode': 'animation_objects', 'role': 'os_object_evidence',
                                                  'scenario_id': 'native.geometry.smoke', 'source_revision': 'a' * 40, 'trial': 1, 'trials': 10}})
        expanded = []
        for row in self.rows:
            run = row['run_id']
            if row['type'] == 'session':
                row.update({'schema_version': 1, 'evidence_kind': 'runtime', 'implementation': 'native', 'native_contract_version': 2,
                            'device': copy.deepcopy(self.geometry), 'environment': copy.deepcopy(self.environment),
                            'configuration': dict(self.configuration, trial=int(run.split('-')[1])),
                            'geometry_probe': {'schema_version': 1, 'accepted': False, 'scope': 'public_geometry_diagnostic_not_contour'},
                            'provenance': {'attempt_id': 'literal-attempt', 'role': 'os_object_evidence', 'native_source_revision': 'a' * 40}})
                expanded.append(row)
                expanded.append({'schema_version': 1, 'type': 'event', 'run_id': run, 'name': 'present.requested', 'data': {}, 'terminal': False})
            elif row['type'] == 'animation_install':
                if row['phase'] in ('fixed320_to_medium', 'medium_to_large', 'large_to_medium'):
                    expanded.append({'schema_version': 1, 'type': 'event', 'run_id': run, 'name': 'detent.requested',
                                     'data': {'target': 'large' if row['phase'] == 'medium_to_large' else 'medium'}, 'terminal': False})
                if row['phase'] == 'dismissal':
                    expanded.append({'schema_version': 1, 'type': 'event', 'run_id': run, 'name': 'dismiss.requested', 'data': {}, 'terminal': False})
                expanded.append(row)
                if row['phase'] == 'presentation':
                    expanded.append({'schema_version': 1, 'type': 'event', 'run_id': run, 'name': 'detent.resolved', 'data': copy.deepcopy(self.resolved), 'terminal': False})
                    expanded.append({'schema_version': 1, 'type': 'event', 'run_id': run, 'name': 'present.completed', 'data': {}, 'terminal': False})
            else:
                row.update({'schema_version': 1, 'data': {}})
                expanded.append(row)
        self.rows = expanded
        seqs = {}
        for row in self.rows:
            run = row['run_id']; row['seq'] = seqs.get(run, 0); seqs[run] = row['seq'] + 1
            row['t_ns'] = int(run.split('-')[1]) * 1000000000 + row['seq']
        self.path = self.root / self.manifest['records_file']
        self.seal()

    def seal(self):
        raw = b''.join(json.dumps(row, sort_keys=True, allow_nan=True).encode() + b'\n' for row in self.rows)
        packed = gzip.compress(raw, mtime=0); self.path.write_bytes(packed)
        self.manifest['compressed_sha256'] = hashlib.sha256(packed).hexdigest()
        self.manifest['raw_sha256'] = hashlib.sha256(raw).hexdigest()
        grouped = {}
        for line, row in zip(raw.splitlines(keepends=True), self.rows):
            grouped.setdefault(row['run_id'], []).append(line)
        self.manifest['runs'] = [{'run_id': run, 'trial': int(run.split('-')[1]),
                                 'raw_sha256': hashlib.sha256(b''.join(lines)).hexdigest(),
                                 'install_count': sum(r['run_id'] == run and r['type'] == 'animation_install' for r in self.rows)}
                                for run, lines in grouped.items()]
        (self.root / 'manifest.json').write_text(json.dumps(self.manifest))

    def reject(self, text):
        self.seal()
        with self.assertRaisesRegex(EvidenceError, text):
            load_animation_objects(self.path)

    def test_accepts_complete_authenticated_objects(self):
        installs = load_animation_objects(self.path)
        self.assertEqual(len(installs), 50)
        self.assertEqual(installs[0].phase, 'presentation')
        self.assertEqual(installs[0].animation['spring']['mass'], 2)

    def test_rejects_compressed_hash_mismatch(self):
        self.path.write_bytes(self.path.read_bytes() + b'x')
        with self.assertRaisesRegex(EvidenceError, 'compressed.*hash'):
            load_animation_objects(self.path)

    def test_rejects_raw_hash_mismatch(self):
        self.manifest['raw_sha256'] = '0' * 64
        (self.root / 'manifest.json').write_text(json.dumps(self.manifest))
        with self.assertRaisesRegex(EvidenceError, 'raw.*hash'):
            load_animation_objects(self.path)

    def test_rejects_every_missing_ca_field(self):
        for key in list(self.install_rows[0]['animation']):
            with self.subTest(field=key):
                original = self.install_rows[0]['animation'].pop(key)
                self.reject('missing.*' + key)
                self.install_rows[0]['animation'][key] = original

    def test_rejects_nonfinite_number(self):
        self.install_rows[0]['animation']['spring']['mass'] = float('nan')
        self.reject('nonfinite')

    def test_preserves_nonfinite_encoded_ca_value_and_excludes_candidate(self):
        self.install_rows[0]['animation']['from_value'] = {'encoding': '{CGPoint=dd}', 'bytes_base64': base64.b64encode(struct.pack('<2d', float('inf'), 2)).decode()}
        # Keep all repetitions bit-identical; no observation is edited by loader.
        for row in self.rows:
            if row['type'] == 'animation_install':
                row['animation']['from_value'] = copy.deepcopy(self.install_rows[0]['animation']['from_value'])
        self.seal()
        installs = load_animation_objects(self.path)
        self.assertFalse(installs[0].eligible_for_math_candidate)
        self.assertIn('from_value', installs[0].nonfinite_motion_fields)

    def test_preserves_tagged_ieee_values_and_excludes_candidate(self):
        for label, bits in [('positive_infinity', '7ff0000000000000'), ('negative_infinity', 'fff0000000000000'), ('nan', '7ff8000000000001')]:
            with self.subTest(label=label):
                tag = {'ieee754': label, 'bits_hex': bits}
                for row in self.rows:
                    if row['type'] == 'animation_install':
                        row['animation']['duration'] = copy.deepcopy(tag)
                self.seal()
                installs = load_animation_objects(self.path)
                self.assertEqual(dict(installs[0].animation['duration']), tag)
                self.assertFalse(installs[0].eligible_for_math_candidate)
                self.assertIn('duration', installs[0].nonfinite_motion_fields)

    def test_rejects_forged_ieee_tag(self):
        self.install_rows[0]['animation']['duration'] = {'ieee754': 'positive_infinity', 'bits_hex': '3ff0000000000000'}
        self.reject('IEEE')

    def test_preserves_opaque_pixel_reference_without_promotion(self):
        opaque = {'opaque_reference': {'cf_type_id': 87, 'runtime_class': '__NSCFType', 'address': '0x2000', 'reason': 'pixel_backing_not_captured'}}
        for row in self.rows:
            if row['type'] == 'animation_install':
                row['animation']['from_value'] = copy.deepcopy(opaque)
        self.seal()
        installs = load_animation_objects(self.path)
        self.assertFalse(installs[0].eligible_for_math_candidate)
        self.assertIn('from_value', installs[0].unresolved_motion_fields)
        self.assertEqual(set(installs[0].animation['from_value']['opaque_reference']), {'cf_type_id', 'runtime_class', 'address', 'reason'})

    def test_rejects_opaque_pixel_bytes_or_description(self):
        for field in ['bytes', 'description']:
            with self.subTest(field=field):
                self.install_rows[0]['animation']['from_value'] = {'opaque_reference': {'cf_type_id': 87, 'runtime_class': '__NSCFType', 'address': '0x2000', 'reason': 'pixel_backing_not_captured', field: 'forbidden'}}
                self.reject('opaque')

    def test_distinct_opaque_objects_preserve_identity_without_parameter_mismatch(self):
        for row in self.rows:
            if row['type'] == 'animation_install':
                row['animation']['from_value'] = {'opaque_reference': {'cf_type_id': 87, 'runtime_class': '__NSCFType', 'address': hex(0x2000 + row['trial']), 'reason': 'pixel_backing_not_captured'}}
        self.seal()
        installs = load_animation_objects(self.path)
        self.assertEqual(installs[0].animation['from_value']['opaque_reference']['address'], '0x2001')
        self.assertEqual(installs[5].animation['from_value']['opaque_reference']['address'], '0x2002')
        self.assertFalse(installs[0].eligible_for_math_candidate)

    def test_missing_overdamping_flag_excludes_math_candidate(self):
        for row in self.rows:
            if row['type'] == 'animation_install':
                row['animation']['spring']['allows_overdamping'] = None
        self.seal()
        installs = load_animation_objects(self.path)
        self.assertFalse(installs[0].eligible_for_math_candidate)
        self.assertIn('spring.allows_overdamping', installs[0].unresolved_motion_fields)

    def test_rejects_inconsistent_repeated_configuration(self):
        self.install_rows[5]['animation']['spring']['stiffness'] = 301
        self.reject('determinism')

    def test_identical_objects_in_different_install_order_are_deterministic(self):
        expanded = []
        for row in self.rows:
            expanded.append(row)
            if row['type'] == 'animation_install':
                second = copy.deepcopy(row); second['key'] = 'second-position'
                second['animation']['duration'] = .8
                expanded.append(second)
        self.rows = expanded; self.manifest['record_count'] = 100
        seq = {}
        for row in self.rows:
            run = row['run_id']; row['seq'] = seq.get(run, 0); seq[run] = row['seq'] + 1
            row['t_ns'] = int(run.split('-')[1]) * 1000000000 + row['seq']
        pair = [row for row in self.rows if row.get('trial') == 2 and row.get('phase') == 'presentation']
        for field in ['key', 'animation']:
            pair[0][field], pair[1][field] = pair[1][field], pair[0][field]
        self.seal()
        installs = load_animation_objects(self.path)
        self.assertEqual(len(installs), 100)
        trial2 = [item for item in installs if item.trial == 2 and item.phase == 'presentation']
        self.assertEqual(trial2[0].record['key'], 'second-position')

    def test_rejects_unresolved_backtrace_image(self):
        self.install_rows[0]['backtrace'][0]['image_uuid'] = None
        self.reject('backtrace')

    def test_rejects_wrong_os_build(self):
        self.rows[0]['os']['build'] = '23G91'
        self.reject('OS')

    def test_rejects_wrong_manifest_os_build(self):
        self.manifest['os']['build'] = '23G91'
        self.reject('OS')

    def test_rejects_sampled_sheet_y(self):
        self.install_rows[0]['sheet.y'] = 123
        self.reject('forbidden')

    def test_rejects_pixel_and_video_data(self):
        for field in ['pixels', 'video', 'sampled_position', 'frame_window']:
            with self.subTest(field=field):
                self.install_rows[0][field] = 'fixture'
                self.reject('forbidden')
                del self.install_rows[0][field]

    def test_rejects_incomplete_trials(self):
        self.rows = [row for row in self.rows if row['run_id'] != 'run-10']
        self.reject('trials')

    def test_rejects_missing_phase(self):
        self.install_rows[0]['phase'] = 'other'
        self.reject('phase')

    def test_rejects_binary_tampering(self):
        self.binary.write_bytes(self.binary.read_bytes() + b'x')
        self.reject('image.*hash')

    def test_rejects_binary_uuid_forgery(self):
        self.manifest['images'][0]['uuid'] = '00000000-0000-0000-0000-000000000000'
        self.reject('UUID')

    def test_rejects_source_tampering(self):
        self.source.write_text('changed\n')
        self.reject('source.*hash')

    def test_rejects_failed_capture(self):
        self.rows[-1]['name'] = 'run.error'
        self.reject('failed|complete')

    def test_rejects_duplicate_run_local_layer_identity(self):
        self.install_rows[1]['layer']['address'] = '0x9999'
        self.reject('layer.*identity')

    def test_rejects_incomplete_layer_model_state(self):
        del self.install_rows[0]['layer']['model_state']['transform']
        self.reject('layer.*state')

    def test_rejects_address_with_multiple_run_local_ids(self):
        self.install_rows[1]['layer']['id'] = 'layer.2'
        self.reject('layer.*identity')

    def test_rejects_parent_without_complete_ancestry(self):
        self.install_rows[0]['layer']['parent_id'] = 'layer.2'
        self.reject('ancestry')

    def test_model_and_current_fallbacks_block_math_candidates(self):
        for field, value in [('model_value', {'ieee754': 'nan', 'bits_hex': '7ff8000000000001'}),
                             ('current_value', {'opaque_reference': {'cf_type_id': 87, 'runtime_class': '__NSCFType', 'address': '0x2000', 'reason': 'pixel_backing_not_captured'}})]:
            with self.subTest(field=field):
                self.install_rows[0]['animation'][field] = value
                self.seal()
                item = load_animation_objects(self.path)[0]
                self.assertFalse(item.eligible_for_math_candidate)
                self.assertIn(field, item.nonfinite_motion_fields + item.unresolved_motion_fields)

    def test_nonfinite_ancestor_coordinate_blocks_math_candidate(self):
        row = self.install_rows[0]; row['layer']['parent_id'] = 'layer.2'
        ancestor = {'id': 'layer.2', 'address': '0x5678', 'class': 'CALayer', 'model_state': copy.deepcopy(row['layer']['model_state']), 'presentation_state': None}
        ancestor['model_state']['position'][1] = {'ieee754': 'positive_infinity', 'bits_hex': '7ff0000000000000'}
        row['layer']['ancestry'] = [ancestor]
        self.seal()
        item = load_animation_objects(self.path)[0]
        self.assertFalse(item.eligible_for_math_candidate)
        self.assertIn('layer.ancestry', item.nonfinite_motion_fields)

    def test_opaque_target_coordinate_blocks_math_candidate(self):
        self.install_rows[0]['layer']['model_state']['position'][1] = {'opaque_reference': {'cf_type_id': 87, 'runtime_class': '__NSCFType', 'address': '0x2000', 'reason': 'pixel_backing_not_captured'}}
        self.seal()
        item = load_animation_objects(self.path)[0]
        self.assertFalse(item.eligible_for_math_candidate)
        self.assertIn('layer.model_state', item.unresolved_motion_fields)

    def test_transition_and_recursive_child_inputs_block_math_candidate(self):
        for row in self.install_rows:
            child = copy.deepcopy(row['animation']); child['model_value'] = {'ieee754': 'nan', 'bits_hex': '7ff8000000000001'}
            row['animation']['children'] = [child]
            row['animation']['transition'] = {'type': 'fade', 'subtype': None, 'start_progress': {'ieee754': 'positive_infinity', 'bits_hex': '7ff0000000000000'}, 'end_progress': 1}
        self.seal()
        item = load_animation_objects(self.path)[0]
        self.assertFalse(item.eligible_for_math_candidate)
        self.assertIn('transition', item.nonfinite_motion_fields)
        self.assertIn('children', item.nonfinite_motion_fields)

    def test_unknown_recursive_child_class_blocks_math_candidate(self):
        for row in self.install_rows:
            child = copy.deepcopy(row['animation']); child['animation_class'] = 'CAMatchPropertyAnimation'
            row['animation']['children'] = [child]
        self.seal()
        self.assertFalse(load_animation_objects(self.path)[0].eligible_for_math_candidate)

    def test_nonzero_begin_time_change_is_not_discarded(self):
        self.install_rows[0]['animation']['begin_time'] = .25
        self.reject('determinism')

    def test_child_relative_delay_is_not_discarded(self):
        for row in self.install_rows:
            row['animation']['children'] = [copy.deepcopy(row['animation'])]
        self.install_rows[0]['animation']['children'][0]['begin_time'] = .25
        self.reject('determinism')

    def test_rejects_session_source_revision_mismatch(self):
        self.rows[0]['provenance']['native_source_revision'] = 'b' * 40
        self.reject('provenance')

    def test_rejects_session_attempt_mismatch(self):
        self.rows[0]['provenance']['attempt_id'] = 'different-attempt'
        self.reject('provenance')

    def test_rejects_session_geometry_mismatch(self):
        self.rows[0]['device']['logical_size'] = {'width': 402, 'height': 874}
        self.reject('geometry')

    def test_rejects_session_environment_mismatch(self):
        self.rows[0]['environment']['system_settings']['reduce_motion'] = True
        self.reject('environment')

    def test_rejects_session_configuration_mismatch(self):
        self.rows[0]['configuration']['page_sizing'] = False
        self.reject('configuration')

    def test_rejects_manifest_run_hash_mismatch(self):
        self.manifest['runs'][0]['raw_sha256'] = '0' * 64
        (self.root / 'manifest.json').write_text(json.dumps(self.manifest))
        with self.assertRaisesRegex(EvidenceError, 'run.*hash'):
            load_animation_objects(self.path)

    def test_rejects_manifest_run_count_mismatch(self):
        self.manifest['runs'][0]['install_count'] = 999
        (self.root / 'manifest.json').write_text(json.dumps(self.manifest))
        with self.assertRaisesRegex(EvidenceError, 'run.*count'):
            load_animation_objects(self.path)

    def test_rejects_wrong_scenario_event_target(self):
        next(row for row in self.rows if row.get('name') == 'detent.requested')['data']['target'] = 'large'
        self.reject('scenario.*event')

    def test_rejects_false_terminal_completion(self):
        self.rows[-1]['terminal'] = False
        self.reject('terminal')

    def test_rejects_unlisted_install_payloads(self):
        for name in ('frame', 'samples', 'motion_samples', 'custom_payload'):
            with self.subTest(name=name):
                self.install_rows[0][name] = {'y': 123, 't': 456}
                self.reject('forbidden')
                del self.install_rows[0][name]

    def test_rejects_unlisted_event_payloads(self):
        self.rows[-1]['data']['frame'] = {'y': 123, 't': 456}
        self.reject('forbidden')

    def test_rejects_sample_payloads_in_string_metadata_slots(self):
        for field in ('key', 'key_path'):
            with self.subTest(field=field):
                for row in self.install_rows:
                    target = row if field == 'key' else row['animation']
                    target[field] = {'frame': {'y': 123, 't': 456}}
                self.reject('forbidden')
                for row in self.install_rows:
                    (row if field == 'key' else row['animation'])[field] = 'position'

    def test_rejects_negative_backtrace_offset(self):
        frame = self.install_rows[0]['backtrace'][0]
        frame.update({'address': '0xff0', 'image_base': '0x1000', 'image_offset': -16})
        self.reject('backtrace.*offset')

    def test_rejects_backtrace_outside_authenticated_executable_mapping(self):
        frame = self.install_rows[0]['backtrace'][0]
        frame.update({'address': '0x4000', 'image_base': '0x1000', 'image_offset': 0x3000})
        self.reject('backtrace.*executable')

    def metadata_fixture(self):
        for row in self.install_rows:
            row['backtrace'][0]['symbol'] = 'literal_symbol'
            row['animation']['transition'] = {'type': 'fade', 'subtype': None, 'start_progress': 0, 'end_progress': 1}
            row['animation']['keyframe'] = {'values': [0, 1], 'key_times': [0, 1], 'timing_functions': None,
                                          'path': None, 'calculation_mode': 'linear', 'rotation_mode': None,
                                          'tension_values': None, 'continuity_values': None, 'bias_values': None}
            row['animation']['from_value'] = {'type': 'CGColor', 'components': [0, 0, 0, 1], 'color_space': 'kCGColorSpaceSRGB'}

    def test_rejects_nested_samples_in_every_string_metadata_category(self):
        slots = [('backtrace', 'symbol'), ('transition', 'type'), ('transition', 'subtype'),
                 ('keyframe', 'calculation_mode'), ('keyframe', 'rotation_mode'), ('color', 'color_space')]
        for section, field in slots:
            for payload in ({'sheet.y': 123}, {'frame': {'y': 123, 't': 456}}, [123, 456], 123, True):
                with self.subTest(section=section, field=field, payload=payload):
                    self.metadata_fixture()
                    targets = [self.install_rows[0]] if section == 'backtrace' else self.install_rows
                    for row in targets:
                        target = row['backtrace'][0] if section == 'backtrace' else row['animation']['from_value'] if section == 'color' else row['animation'][section]
                        target[field] = copy.deepcopy(payload)
                    self.reject('metadata type')

    def test_preserves_valid_optional_null_and_string_metadata(self):
        for value in (None, 'literal_optional'):
            with self.subTest(value=value):
                self.metadata_fixture()
                for row in self.install_rows:
                    row['backtrace'][0]['symbol'] = value
                    row['animation']['transition']['subtype'] = value
                    row['animation']['keyframe']['rotation_mode'] = value
                    row['animation']['from_value']['color_space'] = value
                self.seal()
                item = load_animation_objects(self.path)[0]
                self.assertEqual(item.record['backtrace'][0]['symbol'], value)
                self.assertEqual(item.animation['transition']['subtype'], value)
                self.assertEqual(item.animation['keyframe']['rotation_mode'], value)
                self.assertEqual(item.animation['from_value']['color_space'], value)

    def test_rejects_null_in_required_string_metadata(self):
        for section, field in [('transition', 'type'), ('keyframe', 'calculation_mode')]:
            with self.subTest(section=section):
                self.metadata_fixture()
                for row in self.install_rows:
                    row['animation'][section][field] = None
                self.reject('metadata type')


class OSEquationTests(unittest.TestCase):
    """Kill branch, velocity sign, time-origin and fabricated-cutoff mutations."""

    def spring(self, t, mass=1, stiffness=4, damping=4, velocity=0, overdamping=False):
        self.assertTrue(hasattr(os_motion, 'spring_response'), 'OS solver is missing')
        return os_motion.spring_response(t, mass=mass, stiffness=stiffness, damping=damping,
                                         initial_velocity=velocity, allows_overdamping=overdamping)

    def test_critical_hand_derived_position_velocity_acceleration(self):
        # omega=2, t=.5; e^-1 times (2, 2, 0).
        q, v, a = self.spring(.5)
        self.assertAlmostEqual(q, .26424111765711533, places=15)
        self.assertAlmostEqual(v, .7357588823428847, places=15)
        self.assertEqual(a, 0)

    def test_underdamped_independent_quarter_period_fixture(self):
        # zeta=0, omega=2, t=pi/4 gives cos(pi/2)=0.
        q, v, a = self.spring(math.pi/4, damping=0)
        self.assertAlmostEqual(q, 1, places=15)
        self.assertAlmostEqual(v, 2, places=15)
        self.assertAlmostEqual(a, 0, places=14)

    def test_damped_nonzero_velocity_positive_time_high_precision_fixture(self):
        # Independent 90-digit Taylor sin(1)/cos(1), Decimal exp(-1):
        # beta=wd=1, B=.5; this kills a doubled decay exponent.
        expected=(.6464539518270309601492403961988505859,
                  .5637228686528747679802708330444864967,
                  -.4203536409598114562590224584866741650)
        for allows in (False,True):
            with self.subTest(allows=allows):
                actual=self.spring(1,stiffness=2,damping=2,velocity=.5,overdamping=allows)
                for got,want in zip(actual,expected):
                    self.assertLessEqual(abs(got-want),64*math.ulp(want))

    def test_allowed_over_nonzero_velocity_positive_time_literal_fixtures(self):
        # m=1,k=2,c=3 gives beta=1.5,gamma=.5, roots -2,-1.
        # At log(2) exponentials are 1/4 and 1/2; all expectations
        # below follow by rational arithmetic independent of the helper.
        for velocity,expected in ((.5,(1.125,.5,-1.75)),(-.5,(.875,.5,-1.25))):
            with self.subTest(velocity=velocity):
                actual=self.spring(math.log(2),stiffness=2,damping=3,velocity=velocity,overdamping=True)
                for got,want in zip(actual,expected):
                    self.assertLessEqual(abs(got-want),64*math.ulp(want))

    def test_allowed_over_branch_requires_strictly_greater_zeta(self):
        # zeta==1 with allows=True is critical, as is zeta>1
        # with allows=False. Both use omega=2, B=1.5, t=.5.
        expected=(.35621097794997593720783340221744348197,
                  .73575888234288464319104754032292173489,
                  -.36787944117144232159552377016146086745)
        for damping,allows in ((4,True),(5,False)):
            with self.subTest(damping=damping,allows=allows):
                actual=self.spring(.5,damping=damping,velocity=.5,overdamping=allows)
                for got,want in zip(actual,expected):
                    self.assertLessEqual(abs(got-want),64*math.ulp(want))
        # zeta=1.25 and allows=True selects roots -4,-1,
        # A=1.5,B=-.5, with exp(-4*log2)=1/16, exp(-log2)=1/2.
        actual=self.spring(math.log(2),damping=5,velocity=.5,overdamping=True)
        for got,want in zip(actual,(1.15625,.125,-1.25)):
            self.assertLessEqual(abs(got-want),64*math.ulp(want))

    def test_allowed_overdamped_independent_root_fixture(self):
        # Literal 23G90 update/eval stores fast coefficient +2, slow -1.
        # This statically recovered branch differs from the conventional law.
        q, v, a = self.spring(math.log(2), stiffness=2, damping=3, overdamping=True)
        self.assertAlmostEqual(q, 1, places=15)
        self.assertAlmostEqual(v, .5, places=15)
        self.assertAlmostEqual(a, -1.5, places=14)

    def test_disallowed_overdamping_uses_critical_omega_not_nominal_damping(self):
        self.assertEqual(self.spring(.5, damping=500), self.spring(.5))

    def test_critical_and_under_initial_velocity_sign(self):
        for damping in (0, 2, 4):
            with self.subTest(damping=damping):
                q, v, a = self.spring(0, damping=damping, velocity=3)
                self.assertEqual(q, 0)
                self.assertAlmostEqual(v, 3, places=14)
                self.assertAlmostEqual(a, 4 - damping*3, places=13)

    def test_signed_scalar_additive_composition(self):
        self.assertTrue(hasattr(os_motion, 'interpolate_scalar'), 'OS interpolation is missing')
        q = self.spring(.5)[0]
        self.assertAlmostEqual(os_motion.interpolate_scalar(10, -10, q), 4.715177646857694, places=14)
        self.assertAlmostEqual(os_motion.interpolate_scalar(75, 0, q, additive_base=680), 735.1819161757164, places=12)

    def test_explicit_parent_time_mapping_and_unresolved_zero_begin(self):
        self.assertTrue(hasattr(os_motion, 'animation_local_time'), 'OS time mapping is missing')
        self.assertEqual(os_motion.animation_local_time(11, begin_time=10, speed=.5, time_offset=.1), .6)
        with self.assertRaisesRegex(EvidenceError, 'commit.*epoch'):
            os_motion.animation_local_time(11, begin_time=0, speed=1, time_offset=0)

    def test_media_speed_is_stored_as_float32_before_double_evaluation(self):
        self.assertEqual(os_motion.animation_local_time(11,begin_time=10,speed=.1,time_offset=.1),
                         .20000000149011612)

    def test_invalid_solver_fields_fail_closed(self):
        for kwargs in ({'mass':0}, {'stiffness':-1}, {'damping':-1}, {'velocity':float('nan')}, {'overdamping':1}):
            with self.subTest(kwargs=kwargs), self.assertRaises(EvidenceError):
                self.spring(.1, **kwargs)

    def test_retained_fill_does_not_invent_exact_target_at_duration(self):
        # The actual objects say removed_on_completion=false and fill=both.
        q, v, _ = self.spring(.5058237871186482, stiffness=333.3333332805039,
                              damping=36.51483716411749)
        self.assertAlmostEqual(q, .9990014634632299, places=15)
        self.assertGreater(v, 0)

    def test_uikit_critical_duration_reproduces_binary_approximation(self):
        self.assertTrue(hasattr(os_motion, 'uikit_critical_duration'), 'UIKit duration is missing')
        self.assertEqual(os_motion.uikit_critical_duration(18.257418582058744), .5058237871186482)
        self.assertNotEqual(os_motion.uikit_critical_duration(18.257418582058744), .4)
        self.assertNotEqual(os_motion.uikit_critical_duration(18.257418582058744), .6)


class OSRecoveryTests(unittest.TestCase):
    """Authenticated 23G90 integration: no trajectory inputs or scope borrowing."""

    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[2]
        cls.evidence = cls.root / 'artifacts/native/os_motion_ios26_vphone/animation-objects.jsonl.gz'
        cls.records = load_animation_objects(cls.evidence)
        manifest = json.loads((cls.evidence.parent / 'manifest.json').read_text())
        cls.binaries = {Path(image['runtime_path']).name: Path(image['path'])
                        for image in manifest['images'] if Path(image['runtime_path']).name in ('UIKitCore', 'QuartzCore')}

    def recover(self, records=None, binaries=None):
        self.assertTrue(hasattr(os_motion, 'recover_os_motion'), 'OS recovery is missing')
        return os_motion.recover_os_motion(self.records if records is None else records,
                                           self.binaries if binaries is None else binaries)

    def test_exact_binary_recovery_preserves_actual_object_flags(self):
        report = self.recover().to_dict()
        self.assertEqual(report['install_count'], 1350)
        family = report['solver_families']['detent']
        self.assertEqual(family['omega'], 18.257418582058744)
        self.assertEqual(family['mass'], 1)
        self.assertEqual(family['stiffness'], 333.3333332805039)
        self.assertEqual(family['damping'], 36.51483716411749)
        self.assertEqual(family['duration'], .5058237871186482)
        self.assertEqual(family['timing_function']['name'], 'linear')
        self.assertFalse(family['removed_on_completion'])
        self.assertEqual(family['fill_mode'], 'both')
        self.assertTrue(family['additive'])
        self.assertTrue(all(v['status']=='unresolved' for v in report['phases'].values()))
        self.assertEqual(report['production_profile']['profiles'], [])
        self.assertEqual(set(report['phases']), {'presentation','fixed320_to_medium','medium_to_large','large_to_medium','dismissal'})

    def test_report_is_immutable_and_round_trips_without_mutating_objects(self):
        report = self.recover()
        with self.assertRaises(TypeError):
            report.data['phases']['presentation']['status'] = 'accepted'
        original = report.to_dict()
        changed = report.to_dict(); changed['solver_families']['detent']['mass'] = 99
        self.assertEqual(report.to_dict(), original)

    def test_missing_or_substituted_binary_cannot_recover(self):
        for replacements in ({}, {'UIKitCore':self.binaries['QuartzCore'], 'QuartzCore':self.binaries['QuartzCore']}):
            with self.subTest(replacements=replacements), self.assertRaisesRegex(EvidenceError, 'binary'):
                self.recover(binaries=replacements)

    def test_untrusted_or_incomplete_install_cohort_cannot_recover(self):
        with self.assertRaisesRegex(EvidenceError, 'authenticated.*cohort'):
            self.recover(records=self.records[:-1])

    def test_manifest_recomputed_canonically_and_rejects_manual_edit(self):
        self.assertTrue(hasattr(os_motion, 'validate_motion_manifest'), 'Manifest validator is missing')
        report = self.recover()
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'profile.json'; path.write_bytes(report.profile_bytes())
            os_motion.validate_motion_manifest(path, self.records, self.binaries)
            changed=json.loads(path.read_text()); changed['profiles']=[{'mass':1}]
            path.write_text(json.dumps(changed))
            with self.assertRaisesRegex(EvidenceError, 'canonical'):
                os_motion.validate_motion_manifest(path, self.records, self.binaries)

    def test_manifest_rejects_fit_and_trace_fields(self):
        self.assertTrue(hasattr(os_motion, 'validate_motion_manifest'), 'Manifest validator is missing')
        report = self.recover()
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'profile.json'
            for field in ('fit_report_hash','samples','residual','delay_correction'):
                data=json.loads(report.profile_bytes()); data[field]=[123]
                path.write_text(json.dumps(data))
                with self.subTest(field=field), self.assertRaisesRegex(EvidenceError, 'canonical'):
                    os_motion.validate_motion_manifest(path, self.records, self.binaries)

    def test_saved_artifacts_are_byte_identical_to_authenticated_recovery(self):
        report = self.recover()
        profile = self.root/'spec/motion/ios26_vphone_page.json'
        analysis = self.root/'artifacts/analysis/os_motion_ios26_vphone.json'
        self.assertTrue(profile.exists(), 'Canonical production profile is missing')
        self.assertTrue(analysis.exists(), 'Canonical OS report is missing')
        self.assertEqual(profile.read_bytes(), report.profile_bytes())
        self.assertEqual(analysis.read_bytes(), report.report_bytes())

    def test_detent_coordinates_are_object_offsets_not_a_window_y_fit(self):
        report=self.recover().to_dict()
        phase=report['phases']['medium_to_large']
        position=next(item for item in phase['objects'] if item['key_path']=='position')
        self.assertEqual(position['from_value']['values'], [0,184.5])
        self.assertEqual(position['to_value']['values'], [0,0])
        self.assertEqual(position['layer_state_at_install']['bounds'][3],504)
        self.assertIn('UIKitCore:0x184640c',position['owner_frames'])
        self.assertIn('UIKitCore:0xe9ccd0',position['owner_frames'])
        self.assertFalse(report['detent_configuration_reuse']['medium_to_large']['distance_scaling_promoted'])
        self.assertEqual(report['backtrace_resolution']['UIKitCore:0x184640c']['name'],
                         '-[UISheetPresentationController _animateChanges:completion:]')

    def test_modified_authenticated_record_is_not_trusted_by_python_type(self):
        from dataclasses import replace
        broken=list(self.records)
        broken[0]=replace(broken[0],phase='medium_to_large')
        with self.assertRaisesRegex(EvidenceError,'authenticated.*cohort'):
            self.recover(records=broken)

    def test_binary_instruction_byte_mutation_cannot_recover(self):
        from unittest.mock import patch
        original=Path.read_bytes
        def corrupt(path):
            raw=original(path)
            if path==self.binaries['QuartzCore']:
                raw=raw[:697476]+bytes([raw[697476]^1])+raw[697477:]
            return raw
        with patch.object(Path,'read_bytes',corrupt), self.assertRaisesRegex(EvidenceError,'binary identity'):
            self.recover()

    SUPPLEMENTARY_FUNCTIONS={
        'UIKitCore.0x1891e04cc':(754892,232,'7d72c000ca1ce0cc1389e6ba001f715fa016558fc0f3d39c982ffaf77c6825da'),
        'UIKitCore.0x1891e05b4':(755124,848,'4ce34d5c577fb9345b5695aa02373d82b3dbaedee6b37d569b51b844be1e0c70'),
        'UIKitCore.0x189402884':(2992260,412,'3497da02288e7b7cc6ab116b1a13195f0110ef25b4f25624defc6ec98e33cd65'),
        'UIKitCore.0x189403168':(2994536,264,'579cecd9f25c8e2eef4e6a2b6e166a6eb201431278022e835198890d66efb4f5'),
        'UIKitCore.0x1896cc414':(5915668,664,'6aae1c3614ee06257056350c0637b8666cf045c2811789b935509d02c37d5972'),
    }

    def test_supplementary_artifact_and_functions_bind_canonical_provenance(self):
        report=self.recover().to_dict();profile=report['production_profile']
        relative='research/os_motion/ios26_uikit_attributes_disassembly.txt'
        self.assertEqual(profile['source_hashes'].get(relative),
                         'c7b5995eb72e9ec60161f147b85e0b50bf38bb2adef3df638949b9d88f570a6f')
        for key,(offset,length,digest) in self.SUPPLEMENTARY_FUNCTIONS.items():
            with self.subTest(function=key):
                self.assertIn(key,profile['function_evidence'])
                function=profile['function_evidence'][key]
                self.assertEqual((function['image_offset'],function['file_offset'],function['length'],function['sha256']),
                                 (offset,offset,length,digest))
                self.assertEqual(function,report['function_evidence'][key])

    def test_modified_or_deleted_supplementary_artifact_blocks_recovery_and_validation(self):
        from unittest.mock import patch
        supplemental=self.root/'research/os_motion/ios26_uikit_attributes_disassembly.txt'
        original=Path.read_bytes
        with tempfile.TemporaryDirectory() as temp:
            profile=Path(temp)/'profile.json';profile.write_bytes(self.recover().profile_bytes())
            for missing in (False,True):
                def altered(path):
                    if path==supplemental:
                        if missing:raise FileNotFoundError(str(path))
                        return original(path)+b'altered instruction evidence\n'
                    return original(path)
                for validate in (False,True):
                    with self.subTest(missing=missing,validation=validate):
                        with patch.object(Path,'read_bytes',altered), self.assertRaisesRegex(EvidenceError,'authentication file|evidence hash'):
                            if validate:os_motion.validate_motion_manifest(profile,self.records,self.binaries)
                            else:self.recover()

    def test_supplementary_function_bytes_cannot_be_substituted(self):
        from unittest.mock import patch
        original=Path.read_bytes
        for key,(offset,_,_) in self.SUPPLEMENTARY_FUNCTIONS.items():
            def corrupt(path):
                raw=original(path)
                if path==self.binaries['UIKitCore']:
                    raw=raw[:offset]+bytes([raw[offset]^1])+raw[offset+1:]
                return raw
            with self.subTest(function=key), patch.object(Path,'read_bytes',corrupt), self.assertRaisesRegex(EvidenceError,'binary identity'):
                self.recover()

    def test_supplementary_function_ranges_are_bound_to_actual_nlist_extents(self):
        from unittest.mock import patch
        original=os_motion._json
        binary=self.binaries['UIKitCore'].read_bytes()
        for key,(offset,length,_) in self.SUPPLEMENTARY_FUNCTIONS.items():
            for field in ('image_offset','length'):
                def mutate(data):
                    value=original(data)
                    # Before supplementary inclusion the mutation is ignored;
                    # absence must not make this regression test error out.
                    if type(value) is dict and 'functions' in value and key in value['functions']:
                        entry=value['functions'][key]
                        entry[field] += 4 if field=='image_offset' else -4
                        if field=='length':
                            # Matching short bytes/hash still cannot redefine
                            # an authenticated construction function boundary.
                            entry['sha256']=hashlib.sha256(binary[offset:offset+length-4]).hexdigest()
                    return value
                with self.subTest(function=key,field=field), patch.object(os_motion,'_json',mutate), self.assertRaisesRegex(EvidenceError,'function.*range|function.*offset'):
                    self.recover()

    def test_equation_recovery_opens_only_authenticated_object_and_binary_inputs(self):
        from unittest.mock import patch
        original = Path.read_bytes
        opened=[]
        def observe(path):
            opened.append(str(path)); return original(path)
        with patch.object(Path, 'read_bytes', observe):
            self.recover()
        self.assertTrue(opened)
        self.assertFalse(any('/timing/' in p or 'trace' in Path(p).name or p.endswith(('.mp4','.png')) for p in opened))


if __name__ == '__main__':
    unittest.main()
