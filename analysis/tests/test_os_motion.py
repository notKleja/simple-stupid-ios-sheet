"""Literal install-object fixtures; these are not measured OS parameters."""
import base64
import copy
import gzip
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import uuid

from analysis.os_motion import EvidenceError, load_animation_objects


class OSMotionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.binary_uuid = '0D94422F-FE7C-302E-B896-3BC5873C0CFC'
        self.binary = self.root / 'UIKitCore'
        self.binary.write_bytes(struct.pack('<8I', 0xFEEDFACF, 0x100000C, 2, 6, 1, 24, 0, 0)
                                + struct.pack('<2I', 0x1B, 24) + uuid.UUID(self.binary_uuid).bytes)
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
        self.path = self.root / self.manifest['records_file']
        self.seal()

    def seal(self):
        raw = b''.join(json.dumps(row, sort_keys=True, allow_nan=True).encode() + b'\n' for row in self.rows)
        packed = gzip.compress(raw, mtime=0); self.path.write_bytes(packed)
        self.manifest['compressed_sha256'] = hashlib.sha256(packed).hexdigest()
        self.manifest['raw_sha256'] = hashlib.sha256(raw).hexdigest()
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
        for key in list(self.rows[1]['animation']):
            with self.subTest(field=key):
                original = self.rows[1]['animation'].pop(key)
                self.reject('missing.*' + key)
                self.rows[1]['animation'][key] = original

    def test_rejects_nonfinite_number(self):
        self.rows[1]['animation']['spring']['mass'] = float('nan')
        self.reject('nonfinite')

    def test_preserves_nonfinite_encoded_ca_value_and_excludes_candidate(self):
        self.rows[1]['animation']['from_value'] = {'encoding': '{CGPoint=dd}', 'bytes_base64': base64.b64encode(struct.pack('<2d', float('inf'), 2)).decode()}
        # Keep all repetitions bit-identical; no observation is edited by loader.
        for row in self.rows:
            if row['type'] == 'animation_install':
                row['animation']['from_value'] = copy.deepcopy(self.rows[1]['animation']['from_value'])
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
        self.rows[1]['animation']['duration'] = {'ieee754': 'positive_infinity', 'bits_hex': '3ff0000000000000'}
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
                self.rows[1]['animation']['from_value'] = {'opaque_reference': {'cf_type_id': 87, 'runtime_class': '__NSCFType', 'address': '0x2000', 'reason': 'pixel_backing_not_captured', field: 'forbidden'}}
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
        self.rows[8]['animation']['spring']['stiffness'] = 301
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
        self.rows[1]['backtrace'][0]['image_uuid'] = None
        self.reject('backtrace')

    def test_rejects_wrong_os_build(self):
        self.rows[0]['os']['build'] = '23G91'
        self.reject('OS')

    def test_rejects_wrong_manifest_os_build(self):
        self.manifest['os']['build'] = '23G91'
        self.reject('OS')

    def test_rejects_sampled_sheet_y(self):
        self.rows[1]['sheet.y'] = 123
        self.reject('forbidden')

    def test_rejects_pixel_and_video_data(self):
        for field in ['pixels', 'video', 'sampled_position', 'frame_window']:
            with self.subTest(field=field):
                self.rows[1][field] = 'fixture'
                self.reject('forbidden')
                del self.rows[1][field]

    def test_rejects_incomplete_trials(self):
        self.rows = [row for row in self.rows if row['run_id'] != 'run-10']
        self.reject('trials')

    def test_rejects_missing_phase(self):
        self.rows[1]['phase'] = 'other'
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
        self.rows[2]['layer']['address'] = '0x9999'
        self.reject('layer.*identity')

    def test_rejects_incomplete_layer_model_state(self):
        del self.rows[1]['layer']['model_state']['transform']
        self.reject('layer.*state')

    def test_rejects_address_with_multiple_run_local_ids(self):
        self.rows[2]['layer']['id'] = 'layer.2'
        self.reject('layer.*identity')

    def test_rejects_parent_without_complete_ancestry(self):
        self.rows[1]['layer']['parent_id'] = 'layer.2'
        self.reject('ancestry')


if __name__ == '__main__':
    unittest.main()
