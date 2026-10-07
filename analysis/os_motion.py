"""Authenticate install-boundary evidence; never estimate motion parameters.

The loader is deliberately limited to the staged 23G90 virtual-device cohort.
All CA values remain observations, not production motion profiles. The binary
and source files named by the manifest must be available and match their hashes.
"""
from __future__ import annotations

import base64
from dataclasses import dataclass
import gzip
import hashlib
import json
import math
from pathlib import Path
import re
import struct
from types import MappingProxyType
from typing import Any, Mapping
import uuid


class EvidenceError(ValueError):
    """Evidence is missing, unauthenticated, or outside the capture contract."""


@dataclass(frozen=True)
class AnimationInstall:
    run_id: str
    trial: int
    phase: str
    layer: Mapping[str, Any]
    animation: Mapping[str, Any]
    record: Mapping[str, Any]

    @property
    def nonfinite_motion_fields(self) -> tuple[str, ...]:
        return tuple(key for key in ('duration', 'begin_time', 'time_offset', 'speed', 'repeat_count', 'repeat_duration',
                                     'timing_function', 'spring', 'from_value', 'to_value', 'by_value', 'children', 'keyframe')
                     if _contains_nonfinite(self.animation[key]))

    @property
    def eligible_for_math_candidate(self) -> bool:
        """Only the finite-field gate; this does not establish UIKit ownership."""
        return not self.nonfinite_motion_fields and not self.unresolved_motion_fields

    @property
    def unresolved_motion_fields(self) -> tuple[str, ...]:
        fields = [key for key in ('from_value', 'to_value', 'by_value', 'children', 'keyframe') if _contains_opaque(self.animation[key])]
        spring = self.animation['spring']
        if spring is not None and spring['allows_overdamping'] is None:
            fields.append('spring.allows_overdamping')
        if self.animation['animation_class'] not in ('CASpringAnimation', 'CABasicAnimation', 'CAKeyframeAnimation', 'CAAnimationGroup', 'CATransition'):
            fields.append('animation_class')
        return tuple(fields)


CA_FIELDS = frozenset(('animation_class key_path from_value to_value by_value current_value model_value '
                       'timing_function spring duration begin_time time_offset speed repeat_count repeat_duration '
                       'autoreverses fill_mode additive cumulative removed_on_completion children keyframe transition').split())
PHASES = ('presentation', 'fixed320_to_medium', 'medium_to_large', 'large_to_medium', 'dismissal')
OS = {'version': '26.6.2', 'build': '23G90'}
DEVICE = {'model': 'iPhone99,11', 'runtime_kind': 'virtual_device'}
FORBIDDEN = {'sheet.y', 'sheet.top', 'sheet.velocity_y', 'sheet.acceleration_y', 'pixels', 'pixel', 'video',
             'frames', 'frame_window', 'sampled_position', 'trajectory', 'trajectories', 'screenshot'}


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise EvidenceError(message)


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _read(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except OSError as error:
        raise EvidenceError(f'missing authentication file: {path}') from error


def _json(data: bytes) -> Any:
    try:
        return json.loads(data, parse_constant=lambda value: (_ for _ in ()).throw(EvidenceError('nonfinite JSON: ' + value)))
    except (ValueError, UnicodeError) as error:
        if isinstance(error, EvidenceError):
            raise
        raise EvidenceError('invalid JSON') from error


def _walk(value: Any, path: str = 'record') -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            _require(key.lower() not in FORBIDDEN, 'forbidden sampled/pixel data: ' + path + '.' + key)
            _walk(child, path + '.' + key)
        if 'encoding' in value or 'bytes_base64' in value:
            _require(set(value) == {'encoding', 'bytes_base64'}, 'incomplete encoded CA value')
            encoding = value['encoding']
            _require(isinstance(encoding, str), 'invalid CA encoding')
            # Known scalar and nested numeric structs preserve IEEE bits exactly.
            scalars = re.sub(r'\{[^={}]*=', '', encoding).replace('}', '')
            _require(bool(scalars) and all(c in 'dfcCsSiIlLqQB' for c in scalars), 'unresolved encoded CA value: ' + encoding)
            try:
                raw = base64.b64decode(value['bytes_base64'], validate=True)
                decoded = struct.unpack('<' + scalars.replace('B', '?').replace('l', 'q').replace('L', 'Q'), raw)
            except (ValueError, TypeError, struct.error) as error:
                raise EvidenceError('invalid encoded CA bytes') from error
        if 'ieee754' in value or 'bits_hex' in value:
            _require(set(value) == {'ieee754', 'bits_hex'} and bool(re.fullmatch('[0-9a-f]{16}', value.get('bits_hex', ''))), 'invalid IEEE tag')
            number = struct.unpack('>d', bytes.fromhex(value['bits_hex']))[0]
            expected = 'nan' if math.isnan(number) else ('positive_infinity' if number == math.inf else 'negative_infinity' if number == -math.inf else 'finite')
            _require(expected != 'finite' and value['ieee754'] == expected, 'forged IEEE tag')
        if 'opaque_reference' in value:
            opaque = value['opaque_reference']
            _require(set(value) == {'opaque_reference'} and isinstance(opaque, dict)
                     and set(opaque) == {'cf_type_id', 'runtime_class', 'address', 'reason'}
                     and opaque['reason'] == 'pixel_backing_not_captured'
                     and isinstance(opaque['cf_type_id'], int) and isinstance(opaque['runtime_class'], str)
                     and bool(re.fullmatch('0x[0-9a-f]+', opaque['address'])), 'invalid opaque pixel reference')
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _walk(child, f'{path}.{index}')
    elif isinstance(value, float):
        _require(math.isfinite(value), 'nonfinite value: ' + path)


def _contains_nonfinite(value: Any) -> bool:
    if isinstance(value, Mapping):
        if 'ieee754' in value:
            return True
        if 'encoding' in value:
            scalars = re.sub(r'\{[^={}]*=', '', value['encoding']).replace('}', '')
            decoded = struct.unpack('<' + scalars.replace('B', '?').replace('l', 'q').replace('L', 'Q'), base64.b64decode(value['bytes_base64']))
            return any(isinstance(v, float) and not math.isfinite(v) for v in decoded)
        return any(_contains_nonfinite(child) for child in value.values())
    if isinstance(value, (tuple, list)):
        return any(_contains_nonfinite(child) for child in value)
    return isinstance(value, float) and not math.isfinite(value)


def _contains_opaque(value: Any) -> bool:
    if isinstance(value, Mapping):
        return 'opaque_reference' in value or any(_contains_opaque(v) for v in value.values())
    return isinstance(value, (list, tuple)) and any(_contains_opaque(v) for v in value)


def _number(value: Any) -> bool:
    return (isinstance(value, (int, float)) and not isinstance(value, bool)) or (isinstance(value, dict) and 'ieee754' in value)


def _layer_state(state: Any) -> None:
    arrays = {'position': 2, 'bounds': 4, 'anchor_point': 2, 'transform': 16, 'sublayer_transform': 16}
    _require(isinstance(state, dict) and set(state) == set(arrays) | {'anchor_point_z', 'opacity', 'z_position', 'geometry_flipped'}, 'incomplete layer state')
    for field, count in arrays.items():
        _require(isinstance(state[field], list) and len(state[field]) == count and all(_number(v) for v in state[field]), 'invalid layer state ' + field)
    _require(all(_number(state[k]) for k in ('anchor_point_z', 'opacity', 'z_position'))
             and isinstance(state['geometry_flipped'], bool), 'invalid layer state scalars')


def _binary_uuids(data: bytes) -> set[str]:
    """Read LC_UUID from little-endian 64-bit and fat Mach-O without tools."""
    try:
        magic = data[:4]
        if magic in (b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
            count = struct.unpack_from('>I', data, 4)[0]
            wide = magic == b'\xca\xfe\xba\xbf'; size = 32 if wide else 20
            result = set()
            for index in range(count):
                entry = 8 + index * size
                offset, length = struct.unpack_from('>QQ' if wide else '>II', data, entry + 8)
                result.update(_binary_uuids(data[offset:offset + length]))
            return result
        _require(magic == b'\xcf\xfa\xed\xfe', 'unresolved Mach-O image UUID')
        count = struct.unpack_from('<I', data, 16)[0]; offset = 32; result = set()
        for _ in range(count):
            command, size = struct.unpack_from('<II', data, offset)
            _require(size >= 8 and offset + size <= len(data), 'invalid Mach-O load command')
            if command == 0x1B:
                result.add(str(uuid.UUID(bytes=data[offset + 8:offset + 24])).upper())
            offset += size
        return result
    except (struct.error, ValueError) as error:
        if isinstance(error, EvidenceError):
            raise
        raise EvidenceError('invalid image UUID') from error


def _path(root: Path, name: str) -> Path:
    path = Path(name)
    return path if path.is_absolute() else root / path


def _authenticate_files(root: Path, manifest: dict) -> dict:
    _require(bool(re.fullmatch('[0-9a-f]{40}', manifest.get('native_source_revision', ''))), 'missing committed native source revision')
    _require(bool(manifest.get('source_files')), 'missing source hashes')
    for source in manifest['source_files']:
        _require(_sha(_read(_path(root, source['path']))) == source['sha256'], 'source hash mismatch: ' + source['path'])
    images = {}
    _require(bool(manifest.get('images')), 'missing backtrace image authentication')
    for image in manifest['images']:
        raw = _read(_path(root, image['path']))
        _require(_sha(raw) == image['sha256'], 'image hash mismatch: ' + image['path'])
        _require(image['uuid'] in _binary_uuids(raw), 'image UUID mismatch: ' + image['path'])
        identity = (image['runtime_path'], image['uuid'])
        _require(identity not in images, 'duplicate image authentication')
        images[identity] = image
    return images


def _animation(value: dict) -> None:
    _require(isinstance(value, dict), 'missing CA object')
    missing = CA_FIELDS - set(value)
    _require(not missing, 'missing CA fields: ' + ', '.join(sorted(missing)))
    _require(isinstance(value['animation_class'], str), 'missing animation class')
    for field in ('duration', 'begin_time', 'time_offset', 'speed', 'repeat_count', 'repeat_duration'):
        _require(_number(value[field]), 'invalid CA ' + field)
    for field in ('autoreverses', 'removed_on_completion'):
        _require(isinstance(value[field], bool), 'invalid CA ' + field)
    for field in ('additive', 'cumulative'):
        _require(value[field] is None or isinstance(value[field], bool), 'invalid CA ' + field)
    _require(all(isinstance(value[key], dict) or value[key] >= 0 for key in ('duration', 'repeat_count', 'repeat_duration')), 'negative CA duration/repeat')
    _require(value['fill_mode'] in ('removed', 'forwards', 'backwards', 'both', 'frozen'), 'invalid CA fill mode')
    timing = value['timing_function']
    if timing is not None:
        _require(set(timing) == {'name', 'control_points'}, 'missing timing function fields')
        _require(isinstance(timing['name'], str) and len(timing['control_points']) == 4
                 and all(isinstance(p, list) and len(p) == 2 for p in timing['control_points']), 'invalid timing control points')
    spring = value['spring']
    if spring is not None:
        _require(set(spring) == {'mass', 'stiffness', 'damping', 'initial_velocity', 'settling_duration', 'allows_overdamping'}, 'missing spring fields')
        _require(all(_number(v) for k, v in spring.items() if k != 'allows_overdamping'), 'invalid spring numbers')
        _require(spring['allows_overdamping'] is None or isinstance(spring['allows_overdamping'], bool), 'invalid overdamping selector')
        _require(all(isinstance(spring[k], dict) or spring[k] > 0 for k in ('mass', 'stiffness'))
                 and all(isinstance(spring[k], dict) or spring[k] >= 0 for k in ('damping', 'settling_duration')), 'invalid spring parameters')
    if value['children'] is not None:
        _require(isinstance(value['children'], list), 'invalid group children')
        for child in value['children']:
            _animation(child)


def _configuration(record: dict) -> dict:
    # Time origins and install-instant state are captured verbatim but vary by
    # trial. CA construction fields, including endpoints and every timing flag,
    # must be bit-identical. No averaging, fitting, or parameter extraction.
    def identity_free(value):
        if isinstance(value, dict):
            if 'opaque_reference' in value:
                return {'opaque_reference': {k: v for k, v in value['opaque_reference'].items() if k != 'address'}}
            return {k: identity_free(v) for k, v in value.items()}
        return [identity_free(v) for v in value] if isinstance(value, list) else value
    def object_config(animation):
        return {key: ([object_config(child) for child in value] if key == 'children' and value is not None else identity_free(value))
                for key, value in animation.items() if key not in ('begin_time', 'current_value', 'model_value')}
    return {'key': record['key'], 'layer_class': record['layer']['class'], 'animation': object_config(record['animation'])}


def _freeze(value: Any) -> Any:
    if isinstance(value, dict):
        return MappingProxyType({key: _freeze(child) for key, child in value.items()})
    if isinstance(value, list):
        return tuple(_freeze(child) for child in value)
    return value


def load_animation_objects(path: str | Path) -> list[AnimationInstall]:
    path = Path(path); root = path.parent
    try:
        manifest = _json(_read(root / 'manifest.json'))
        _walk(manifest, 'manifest')
        _require(manifest.get('schema_version') == 1 and manifest.get('evidence_kind') == 'runtime_animation_install'
                 and manifest.get('capture_mode') == 'animation_objects', 'wrong evidence capture mode')
        _require(manifest.get('os') == OS, 'wrong manifest OS')
        _require(manifest.get('device') == DEVICE, 'wrong manifest device')
        _require(manifest.get('scenario_id') == 'native.geometry.smoke', 'wrong scenario')
        _require(manifest.get('trial_count') == 10, 'expected ten trials')
        _require(path.name == manifest.get('records_file'), 'wrong evidence file')
        compressed = _read(path)
        _require(_sha(compressed) == manifest.get('compressed_sha256'), 'compressed evidence hash mismatch')
        try:
            raw = gzip.decompress(compressed)
        except (OSError, EOFError) as error:
            raise EvidenceError('invalid compressed evidence') from error
        _require(_sha(raw) == manifest.get('raw_sha256'), 'raw evidence hash mismatch')
        images = _authenticate_files(root, manifest)
        rows = [_json(line) for line in raw.splitlines()]
        runs = {}; installs = []; identities = {}; addresses = {}; phases = {}; completed = set(); sequences = {}; last_time = {}
        for row in rows:
            _walk(row)
            kind = row.get('type'); run = row.get('run_id')
            _require(kind in ('session', 'event', 'animation_install'), 'forbidden record type')
            _require(isinstance(run, str) and run, 'missing run identity')
            _require(row.get('seq') == sequences.get(run, 0), 'invalid run sequence')
            sequences[run] = sequences.get(run, 0) + 1
            _require(isinstance(row.get('t_ns'), int) and row['t_ns'] >= last_time.get(run, 0), 'nonmonotonic install time')
            last_time[run] = row['t_ns']
            if kind == 'session':
                _require(run not in runs, 'duplicate session')
                _require(row.get('os') == OS, 'wrong session OS')
                _require(all(row.get('device', {}).get(k) == v for k, v in DEVICE.items()), 'wrong session device')
                _require(row.get('capture_mode') == 'animation_objects' and row.get('scenario_id') == 'native.geometry.smoke', 'wrong session capture')
                runs[run] = row['configuration']['trial']; phases[run] = {phase: [] for phase in PHASES}
            elif kind == 'event':
                _require(run in runs, 'event outside session')
                _require(row.get('name') != 'run.error', 'failed capture')
                if row.get('name') == 'dismiss.completed':
                    completed.add(run)
            else:
                _require(run in runs and run not in completed, 'install outside run lifetime')
                phase = row.get('phase'); _require(phase in PHASES, 'unknown motion phase')
                _require(row.get('trial') == runs[run], 'wrong install trial')
                _require(isinstance(row.get('transaction_time'), (float, int)), 'missing transaction time')
                _require(set(row.get('transaction', {})) == {'duration', 'disable_actions', 'timing_function'}, 'missing transaction fields')
                layer = row.get('layer', {})
                _require(set(layer) == {'id', 'address', 'class', 'parent_id', 'model_state', 'presentation_state', 'ancestry'}, 'missing layer fields')
                ancestry = layer['ancestry']
                _require(isinstance(ancestry, list) and layer['parent_id'] == (ancestry[0]['id'] if ancestry else None), 'incomplete layer ancestry')
                chain = [layer] + ancestry
                _require(len({node['id'] for node in chain}) == len(chain), 'cyclic layer ancestry')
                for node in chain:
                    if node is not layer:
                        _require(set(node) == {'id', 'address', 'class', 'model_state', 'presentation_state'}, 'incomplete layer ancestry')
                    _require(isinstance(node['id'], str) and isinstance(node['class'], str)
                             and isinstance(node['address'], str) and bool(re.fullmatch('0x[0-9a-f]+', node['address'])), 'missing layer identity')
                    identity = (run, node['id']); stable = (node['address'], node['class'])
                    address_key = (run, node['address'])
                    _require(identity not in identities or identities[identity] == stable, 'layer identity changed')
                    _require(address_key not in addresses or addresses[address_key] == node['id'], 'layer address identity changed')
                    identities[identity] = stable; addresses[address_key] = node['id']
                    _layer_state(node['model_state'])
                    if node['presentation_state'] is not None:
                        _layer_state(node['presentation_state'])
                _require('key' in row, 'missing installation key')
                _animation(row.get('animation'))
                frames = row.get('backtrace'); _require(isinstance(frames, list) and bool(frames), 'missing backtrace')
                for frame in frames:
                    _require(set(frame) == {'address', 'image', 'image_uuid', 'image_base', 'image_offset', 'symbol', 'symbol_address'}, 'missing backtrace fields')
                    _require((frame['image'], frame['image_uuid']) in images, 'unresolved backtrace image')
                    _require(int(frame['address'], 16) - int(frame['image_base'], 16) == frame['image_offset'], 'invalid backtrace image offset')
                phases[run][phase].append(_configuration(row))
                frozen = _freeze(row)
                installs.append(AnimationInstall(run, row['trial'], phase, frozen['layer'], frozen['animation'], frozen))
        _require(len(runs) == 10 and set(runs.values()) == set(range(1, 11)), 'incomplete trials')
        _require(completed == set(runs), 'incomplete dismissal capture')
        _require(len(installs) == manifest.get('record_count'), 'wrong animation record count')
        # UIKit's concurrent property-action dictionaries need not enumerate in
        # the same order. Preserve raw order, compare exact multisets with full
        # multiplicity, and reject even one changed construction coefficient.
        signatures = [{phase: sorted(json.dumps(config, sort_keys=True, separators=(',', ':')) for config in configs)
                       for phase, configs in value.items()} for value in phases.values()]
        baseline = signatures[0]
        _require(all(baseline[phase] for phase in PHASES), 'missing motion phase objects')
        _require(all(value == baseline for value in signatures), 'object configuration determinism mismatch')
        return installs
    except (KeyError, TypeError, IndexError, ValueError) as error:
        if isinstance(error, EvidenceError):
            raise
        raise EvidenceError('malformed animation evidence: ' + str(error)) from error
