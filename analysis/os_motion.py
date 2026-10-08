"""Authenticate install-boundary evidence; never estimate motion parameters.

The loader is deliberately limited to the staged 23G90 virtual-device cohort.
All CA values remain observations, not production motion profiles. The binary
and source files named by the manifest must be available and match their hashes.
"""
from __future__ import annotations

import base64
import bisect
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
        fields = [key for key, value in self.animation.items() if _contains_nonfinite(value)]
        fields += ['layer.' + key for key in ('model_state', 'presentation_state', 'ancestry') if _contains_nonfinite(self.layer[key])]
        fields += ['transaction'] if _contains_nonfinite(self.record['transaction']) else []
        return tuple(fields)

    @property
    def eligible_for_math_candidate(self) -> bool:
        """Only the finite-field gate; this does not establish UIKit ownership."""
        return not self.nonfinite_motion_fields and not self.unresolved_motion_fields

    @property
    def unresolved_motion_fields(self) -> tuple[str, ...]:
        fields = [key for key, value in self.animation.items() if _contains_opaque(value)]
        fields += ['layer.' + key for key in ('model_state', 'presentation_state', 'ancestry') if _contains_opaque(self.layer[key])]
        if any(_unresolved_animation(child) for child in self.animation['children'] or ()):
            fields.append('children')
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


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise EvidenceError(message)


def _schema(value: Any, required, optional=(), *, context: str) -> None:
    required = set(required); optional = set(optional)
    _require(isinstance(value, dict), 'missing ' + context + ' object')
    _require(not (required - set(value)), 'missing ' + context + ' fields: ' + ', '.join(sorted(required - set(value))))
    _require(set(value) <= required | optional, 'forbidden extra ' + context + ' fields: ' + ', '.join(sorted(set(value) - required - optional)))


def _metadata_types(value: dict, *, strings=(), nullable_strings=(), integers=(), numbers=(), booleans=(), context: str) -> None:
    """Validate declared metadata leaves; CA data/tag schemas stay separate."""
    rules = ((strings, lambda v: type(v) is str),
             (nullable_strings, lambda v: v is None or type(v) is str),
             (integers, lambda v: type(v) is int),
             (numbers, lambda v: type(v) in (int, float)),
             (booleans, lambda v: type(v) is bool))
    for fields, valid in rules:
        for field in fields:
            if field in value:
                _require(valid(value[field]), 'forbidden ' + context + ' metadata type: ' + field)


CONFIG_FIELDS = frozenset(('detents edge_attached_in_compact_height grabber largest_undimmed modal_in_presentation '
                           'page_sizing placement preferred_content_size presentation_style scroll_expansion surface width_follows_preferred_content_size').split())
COMMON_FIELDS = frozenset('schema_version type run_id seq t_ns'.split())
SCENARIO_EVENTS = (('present.requested', {}), ('present.completed', {}), ('detent.requested', {'target': 'medium'}),
                   ('detent.requested', {'target': 'large'}), ('detent.requested', {'target': 'medium'}),
                   ('dismiss.requested', {}), ('dismiss.completed', {}))


def _geometry_schema(value: dict) -> None:
    _schema(value, 'model runtime_kind logical_size physical_size scale refresh_hz refresh_hz_source'.split(), context='device geometry')
    _metadata_types(value, strings=('model', 'runtime_kind', 'refresh_hz_source'), numbers=('scale', 'refresh_hz'), context='device geometry')
    for key in ('logical_size', 'physical_size'):
        _schema(value[key], ('width', 'height'), context='device geometry ' + key)
        _metadata_types(value[key], numbers=('width', 'height'), context='device size')
    _require(value['logical_size'] == {'width': 430, 'height': 932}
             and value['physical_size'] == {'width': 1290, 'height': 2796} and value['scale'] == 3, 'wrong cohort geometry')


def _environment_schema(value: dict) -> None:
    _schema(value, 'orientation safe_area size_classes status_bar keyboard system_settings'.split(), context='environment')
    _schema(value['safe_area'], ('top', 'left', 'right', 'bottom'), context='safe area')
    _schema(value['size_classes'], ('horizontal', 'vertical'), context='size classes')
    _schema(value['status_bar'], ('hidden',), context='status bar')
    _schema(value['system_settings'], ('reduce_motion', 'voice_over', 'content_size_category'), context='system settings')
    _schema(value['keyboard'], ('visible', 'frame'), context='static keyboard')
    _schema(value['keyboard']['frame'], ('x', 'y', 'width', 'height'), context='static keyboard rectangle')
    _metadata_types(value, strings=('orientation',), context='environment')
    _metadata_types(value['safe_area'], numbers=('top', 'left', 'right', 'bottom'), context='safe area')
    _metadata_types(value['size_classes'], strings=('horizontal', 'vertical'), context='size classes')
    _metadata_types(value['status_bar'], booleans=('hidden',), context='status bar')
    _metadata_types(value['system_settings'], strings=('content_size_category',), booleans=('reduce_motion', 'voice_over'), context='system settings')
    _metadata_types(value['keyboard'], booleans=('visible',), context='keyboard')
    _metadata_types(value['keyboard']['frame'], numbers=('x', 'y', 'width', 'height'), context='static keyboard rectangle')
    _require(value['keyboard'] == {'visible': False, 'frame': {'x': 0, 'y': 0, 'width': 0, 'height': 0}}, 'wrong static keyboard configuration')


def _configuration_schema(value: dict, session=False) -> None:
    _schema(value, CONFIG_FIELDS | ({'trial'} if session else set()), context='scenario configuration')
    _schema(value['preferred_content_size'], ('width', 'height'), context='preferred content size')
    _metadata_types(value, strings=('placement', 'presentation_style', 'surface'), nullable_strings=('largest_undimmed',),
                    integers=('trial',), booleans=('edge_attached_in_compact_height', 'grabber', 'modal_in_presentation',
                                                  'page_sizing', 'scroll_expansion', 'width_follows_preferred_content_size'), context='configuration')
    _metadata_types(value['preferred_content_size'], numbers=('width', 'height'), context='preferred size')
    _require(type(value['detents']) is list and all(type(v) is str for v in value['detents']), 'forbidden detent metadata type')


def _manifest_schema(value: dict) -> None:
    _schema(value, ('schema_version evidence_kind capture_mode scenario_id os device trial_count record_count records_file '
                    'native_source_revision source_files images compressed_sha256 raw_sha256 capture_request configuration '
                    'environment device_geometry resolved_detents runs').split(), ('determinism_policy', 'promotion_status'), context='manifest')
    _schema(value['os'], ('version', 'build'), context='OS')
    _schema(value['device'], ('model', 'runtime_kind'), context='device')
    _metadata_types(value, strings=('evidence_kind', 'capture_mode', 'scenario_id', 'records_file', 'native_source_revision',
                                   'compressed_sha256', 'raw_sha256', 'promotion_status'), integers=('schema_version', 'trial_count', 'record_count'), context='manifest')
    _metadata_types(value['os'], strings=('version', 'build'), context='OS')
    _metadata_types(value['device'], strings=('model', 'runtime_kind'), context='device')
    _geometry_schema(value['device_geometry']); _environment_schema(value['environment']); _configuration_schema(value['configuration'])
    _schema(value['resolved_detents'], ('fixed', 'medium', 'large', 'maximum'), context='resolved detents')
    _metadata_types(value['resolved_detents'], numbers=('fixed', 'medium', 'large', 'maximum'), context='resolved detents')
    request = value['capture_request']
    _schema(request, 'attempt_id capture_mode role scenario_id source_revision trial trials'.split(), context='capture request')
    _metadata_types(request, strings=('attempt_id', 'capture_mode', 'role', 'scenario_id', 'source_revision'), integers=('trial', 'trials'), context='capture request')
    _require(request['source_revision'] == value['native_source_revision'] and request['capture_mode'] == value['capture_mode']
             and request['scenario_id'] == value['scenario_id'] and request['trial'] == 1 and request['trials'] == 10
             and request['role'] == 'os_object_evidence' and isinstance(request['attempt_id'], str) and request['attempt_id'], 'capture request provenance mismatch')
    for source in value['source_files']:
        _schema(source, ('path', 'sha256'), ('repository_path',), context='source authentication')
        _metadata_types(source, strings=('path', 'sha256', 'repository_path'), context='source authentication')
    for image in value['images']:
        _schema(image, ('path', 'sha256', 'runtime_path', 'uuid'), context='image authentication')
        _metadata_types(image, strings=('path', 'sha256', 'runtime_path', 'uuid'), context='image authentication')
    for run in value['runs']:
        _schema(run, ('run_id', 'trial', 'raw_sha256', 'install_count'), context='manifest run')
        _metadata_types(run, strings=('run_id', 'raw_sha256'), integers=('trial', 'install_count'), context='manifest run')
    if 'determinism_policy' in value:
        _schema(value['determinism_policy'], ('fields', 'excluded'), ('begin_time_policy',), context='determinism policy')
        _metadata_types(value['determinism_policy'], strings=('fields', 'begin_time_policy'), context='determinism policy')
        _require(type(value['determinism_policy']['excluded']) is list and all(type(v) is str for v in value['determinism_policy']['excluded']), 'forbidden exclusion metadata type')
        _require('begin_time' not in value['determinism_policy']['excluded'], 'begin_time semantics cannot be excluded')


def _record_schema(row: dict) -> None:
    _require(isinstance(row, dict), 'missing record object')
    _metadata_types(row, strings=('type', 'run_id'), integers=('schema_version', 'seq', 't_ns'), context='record')
    kind = row.get('type')
    if kind == 'animation_install':
        _schema(row, COMMON_FIELDS | set('trial phase transaction_time layer key animation transaction backtrace'.split()), context='animation install')
        _require(row['key'] is None or isinstance(row['key'], str), 'forbidden installation key payload')
        _metadata_types(row, strings=('phase',), integers=('trial',), numbers=('transaction_time',), context='install')
    elif kind == 'session':
        _schema(row, COMMON_FIELDS | set(('capture_mode configuration device environment evidence_kind geometry_probe implementation '
                                          'native_contract_version os provenance scenario_id').split()), context='session')
        _schema(row['os'], ('version', 'build'), context='OS')
        _geometry_schema(row['device']); _environment_schema(row['environment']); _configuration_schema(row['configuration'], session=True)
        _schema(row['provenance'], ('attempt_id', 'role', 'native_source_revision'), context='session provenance')
        _schema(row['geometry_probe'], ('accepted', 'schema_version', 'scope'), context='geometry probe scope')
        _metadata_types(row, strings=('capture_mode', 'evidence_kind', 'implementation', 'scenario_id'), integers=('native_contract_version',), context='session')
        _metadata_types(row['os'], strings=('version', 'build'), context='OS')
        _metadata_types(row['provenance'], strings=('attempt_id', 'role', 'native_source_revision'), context='provenance')
        _metadata_types(row['geometry_probe'], strings=('scope',), integers=('schema_version',), booleans=('accepted',), context='geometry probe')
        _require(row['implementation'] == 'native' and row['evidence_kind'] == 'runtime' and row['native_contract_version'] == 2
                 and row['geometry_probe'] == {'accepted': False, 'schema_version': 1, 'scope': 'public_geometry_diagnostic_not_contour'}, 'wrong session evidence scope')
    elif kind == 'event':
        _require(row.get('name') != 'run.error', 'failed capture')
        _schema(row, COMMON_FIELDS | {'name', 'data', 'terminal'}, context='event')
        _metadata_types(row, strings=('name',), booleans=('terminal',), context='event')
        _require(isinstance(row['terminal'], bool), 'invalid event terminal flag')
        name = row['name']
        fields = {'detent.resolved': ('fixed', 'medium', 'large', 'maximum'), 'detent.requested': ('target',), 'batch.completed': ('trials',)}
        _require(name in fields or name in ('present.requested', 'present.completed', 'dismiss.requested', 'dismiss.completed'), 'forbidden scenario event name')
        _schema(row['data'], fields.get(name, ()), context='event data')
        _metadata_types(row['data'], strings=('target',), numbers=('fixed', 'medium', 'large', 'maximum'), integers=('trials',), context='event data')
        _require(row['terminal'] == (name == 'dismiss.completed'), 'invalid terminal completion flag')
    else:
        raise EvidenceError('forbidden record type')
    _require(row['schema_version'] == 1, 'wrong record schema')


def _ca_value_schema(value: Any) -> None:
    if isinstance(value, dict):
        if 'encoding' in value:
            _schema(value, ('encoding', 'bytes_base64'), context='encoded CA value')
            _metadata_types(value, strings=('encoding', 'bytes_base64'), context='encoded CA value')
        elif 'ieee754' in value:
            _schema(value, ('ieee754', 'bits_hex'), context='IEEE tag')
            _metadata_types(value, strings=('ieee754', 'bits_hex'), context='IEEE tag')
        elif 'opaque_reference' in value:
            _schema(value, ('opaque_reference',), context='opaque reference')
            _schema(value['opaque_reference'], ('cf_type_id', 'runtime_class', 'address', 'reason'), context='opaque reference')
            _metadata_types(value['opaque_reference'], strings=('runtime_class', 'address', 'reason'), integers=('cf_type_id',), context='opaque reference')
        elif value.get('type') == 'CGColor':
            _schema(value, ('type', 'components', 'color_space'), context='CGColor value')
            _metadata_types(value, strings=('type',), nullable_strings=('color_space',), context='CGColor')
            _ca_value_schema(value['components'])
        elif value.get('type') == 'CGPath':
            _schema(value, ('type', 'elements'), context='CGPath value')
            for element in value['elements']:
                _schema(element, ('type', 'points'), context='CGPath element'); _ca_value_schema(element['points'])
                _metadata_types(element, integers=('type',), context='CGPath element')
        else:
            raise EvidenceError('forbidden unlisted CA value payload')
    elif isinstance(value, list):
        for child in value:
            _ca_value_schema(child)
    else:
        _require(value is None or isinstance(value, (str, int, float, bool)), 'unsupported CA value')


def _timing_schema(value: Any) -> None:
    if value is not None:
        _schema(value, ('name', 'control_points'), context='timing function')
        _metadata_types(value, strings=('name',), context='timing function')
        _ca_value_schema(value['control_points'])


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


def _unresolved_animation(animation: Mapping) -> bool:
    return (animation['animation_class'] not in ('CASpringAnimation', 'CABasicAnimation', 'CAKeyframeAnimation', 'CAAnimationGroup', 'CATransition')
            or (animation['spring'] is not None and animation['spring']['allows_overdamping'] is None)
            or any(_unresolved_animation(child) for child in animation['children'] or ()))


def _number(value: Any) -> bool:
    return (isinstance(value, (int, float)) and not isinstance(value, bool)) or (isinstance(value, dict) and 'ieee754' in value)


def _layer_state(state: Any) -> None:
    arrays = {'position': 2, 'bounds': 4, 'anchor_point': 2, 'transform': 16, 'sublayer_transform': 16}
    _require(isinstance(state, dict) and set(state) == set(arrays) | {'anchor_point_z', 'opacity', 'z_position', 'geometry_flipped'}, 'incomplete layer state')
    def coordinate(value):
        if _number(value):
            return True
        if isinstance(value, dict) and 'opaque_reference' in value:
            _ca_value_schema(value); return True
        return False
    for field, count in arrays.items():
        _require(isinstance(state[field], list) and len(state[field]) == count and all(coordinate(v) for v in state[field]), 'invalid layer state ' + field)
    _require(all(coordinate(state[k]) for k in ('anchor_point_z', 'opacity', 'z_position'))
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


def _executable_mappings(data: bytes) -> dict[str, tuple[tuple[int, int], ...]]:
    """Derive executable VM ranges from authenticated Mach-O load commands."""
    try:
        magic = data[:4]
        if magic in (b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
            count = struct.unpack_from('>I', data, 4)[0]; wide = magic == b'\xca\xfe\xba\xbf'
            result = {}
            for index in range(count):
                offset, size = struct.unpack_from('>QQ' if wide else '>II', data, 8 + index * (32 if wide else 20) + 8)
                result.update(_executable_mappings(data[offset:offset + size]))
            return result
        _require(magic == b'\xcf\xfa\xed\xfe', 'unresolved executable image mapping')
        count = struct.unpack_from('<I', data, 16)[0]; offset = 32; segments = []; image_uuid = None
        for _ in range(count):
            command, size = struct.unpack_from('<II', data, offset)
            _require(size >= 8 and offset + size <= len(data), 'invalid executable load command')
            if command == 0x1B:
                image_uuid = str(uuid.UUID(bytes=data[offset + 8:offset + 24])).upper()
            elif command == 0x19:
                _require(size >= 72, 'incomplete executable segment')
                name = data[offset + 8:offset + 24].split(b'\0')[0]
                vmaddr, vmsize, fileoff, filesize = struct.unpack_from('<4Q', data, offset + 24)
                initprot = struct.unpack_from('<I', data, offset + 60)[0]
                segments.append((name, vmaddr, vmsize, fileoff, filesize, initprot))
            offset += size
        text = next((segment for segment in segments if segment[0] == b'__TEXT'), None)
        _require(text is not None and image_uuid is not None, 'unresolved executable image mapping')
        base = text[1]
        ranges = tuple((segment[1] - base, segment[1] - base + segment[2]) for segment in segments if segment[5] & 4)
        _require(bool(ranges) and all(start >= 0 and end > start for start, end in ranges), 'invalid executable image mapping')
        return {image_uuid: ranges}
    except (struct.error, ValueError, StopIteration) as error:
        if isinstance(error, EvidenceError):
            raise
        raise EvidenceError('unresolved executable image mapping') from error


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
        mappings = _executable_mappings(raw)
        _require(image['uuid'] in mappings, 'unresolved executable image UUID')
        images[identity] = dict(image, executable_ranges=mappings[image['uuid']])
    return images


def _animation(value: dict) -> None:
    _require(isinstance(value, dict), 'missing CA object')
    missing = CA_FIELDS - set(value)
    _require(not missing, 'missing CA fields: ' + ', '.join(sorted(missing)))
    _schema(value, CA_FIELDS, context='CA animation')
    _require(isinstance(value['animation_class'], str), 'missing animation class')
    _require(value['key_path'] is None or isinstance(value['key_path'], str), 'forbidden key path payload')
    for field in ('from_value', 'to_value', 'by_value', 'current_value', 'model_value'):
        _ca_value_schema(value[field])
    _timing_schema(value['timing_function'])
    if value['transition'] is not None:
        _schema(value['transition'], ('type', 'subtype', 'start_progress', 'end_progress'), context='CA transition')
        _metadata_types(value['transition'], strings=('type',), nullable_strings=('subtype',), context='transition')
        _require(_number(value['transition']['start_progress']) and _number(value['transition']['end_progress']), 'invalid transition progress')
    if value['keyframe'] is not None:
        _schema(value['keyframe'], ('values key_times timing_functions path calculation_mode rotation_mode tension_values continuity_values bias_values').split(), context='CA keyframe')
        _metadata_types(value['keyframe'], strings=('calculation_mode',), nullable_strings=('rotation_mode',), context='keyframe')
        for field in ('values', 'key_times', 'path', 'tension_values', 'continuity_values', 'bias_values'):
            _ca_value_schema(value['keyframe'][field])
        for timing in value['keyframe']['timing_functions'] or []:
            _timing_schema(timing)
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
                for key, value in animation.items() if key not in ('current_value', 'model_value')}
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
        _manifest_schema(manifest)
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
        raw_lines = raw.splitlines(keepends=True)
        rows = [_json(line) for line in raw_lines]
        declared_runs = {run['run_id']: run for run in manifest['runs']}
        _require(len(declared_runs) == len(manifest['runs']) == 10
                 and {run['trial'] for run in declared_runs.values()} == set(range(1, 11)), 'incomplete manifest trials')
        run_bytes = {}; run_counts = {}
        for line, row in zip(raw_lines, rows):
            run = row.get('run_id'); run_bytes.setdefault(run, []).append(line)
            run_counts[run] = run_counts.get(run, 0) + (row.get('type') == 'animation_install')
        _require(set(run_bytes) == set(declared_runs), 'manifest run identity mismatch')
        for run, lines in run_bytes.items():
            _require(_sha(b''.join(lines)) == declared_runs[run]['raw_sha256'], 'manifest run raw hash mismatch')
            _require(run_counts[run] == declared_runs[run]['install_count'], 'manifest run install count mismatch')
        runs = {}; installs = []; identities = {}; addresses = {}; phases = {}; completed = set(); sequences = {}; last_time = {}
        event_index = {}; active_phase = {}; batch_completed = set()
        for row in rows:
            _record_schema(row)
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
                request = manifest['capture_request']; provenance = row['provenance']
                _require(provenance == {'attempt_id': request['attempt_id'], 'role': request['role'],
                                        'native_source_revision': manifest['native_source_revision']}, 'session provenance mismatch')
                _require(row['device'] == manifest['device_geometry'], 'session geometry mismatch')
                _require(row['environment'] == manifest['environment'], 'session environment mismatch')
                _require({k: v for k, v in row['configuration'].items() if k != 'trial'} == manifest['configuration'], 'session configuration mismatch')
                _require(row['configuration']['trial'] == declared_runs[run]['trial'], 'session/manifest trial mismatch')
                runs[run] = row['configuration']['trial']; phases[run] = {phase: [] for phase in PHASES}
                event_index[run] = 0; active_phase[run] = None
            elif kind == 'event':
                _require(run in runs, 'event outside session')
                _require(row.get('name') != 'run.error', 'failed capture')
                name = row['name']
                if name == 'detent.resolved':
                    _require(run not in completed and event_index[run] > 0 and row['data'] == manifest['resolved_detents'], 'scenario resolved-detent event mismatch')
                elif name == 'batch.completed':
                    _require(run in completed and runs[run] == 10 and run not in batch_completed and row['data'] == {'trials': 10}, 'invalid scenario batch event')
                    batch_completed.add(run)
                else:
                    index = event_index[run]
                    _require(index < len(SCENARIO_EVENTS) and (name, row['data']) == SCENARIO_EVENTS[index], 'wrong scenario event sequence or target')
                    event_index[run] += 1
                    if index in (0, 2, 3, 4, 5):
                        active_phase[run] = {0: 'presentation', 2: 'fixed320_to_medium', 3: 'medium_to_large', 4: 'large_to_medium', 5: 'dismissal'}[index]
                    if name == 'dismiss.completed':
                        _require(row['terminal'] is True, 'dismissal terminal flag missing'); completed.add(run)
            else:
                _require(run in runs and run not in completed, 'install outside run lifetime')
                phase = row.get('phase'); _require(phase in PHASES, 'unknown motion phase')
                _require(phase == active_phase[run], 'install phase disagrees with scenario event boundary')
                _require(row.get('trial') == runs[run], 'wrong install trial')
                _require(isinstance(row.get('transaction_time'), (float, int)), 'missing transaction time')
                _require(set(row.get('transaction', {})) == {'duration', 'disable_actions', 'timing_function'}, 'missing transaction fields')
                _require(_number(row['transaction']['duration']) and isinstance(row['transaction']['disable_actions'], bool), 'invalid transaction state')
                _timing_schema(row['transaction']['timing_function'])
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
                    _metadata_types(frame, strings=('address', 'image', 'image_uuid', 'image_base'), nullable_strings=('symbol', 'symbol_address'), integers=('image_offset',), context='backtrace')
                    _require((frame['image'], frame['image_uuid']) in images, 'unresolved backtrace image')
                    _require(isinstance(frame['image_offset'], int) and not isinstance(frame['image_offset'], bool)
                             and frame['image_offset'] >= 0, 'invalid backtrace image offset')
                    _require(int(frame['address'], 16) - int(frame['image_base'], 16) == frame['image_offset'], 'invalid backtrace image offset')
                    ranges = images[(frame['image'], frame['image_uuid'])]['executable_ranges']
                    _require(any(start <= frame['image_offset'] < end for start, end in ranges), 'backtrace outside authenticated executable mapping')
                    if frame['symbol_address'] is not None:
                        symbol_offset = int(frame['symbol_address'], 16) - int(frame['image_base'], 16)
                        _require(any(start <= symbol_offset < end for start, end in ranges), 'backtrace symbol outside authenticated executable mapping')
                phases[run][phase].append(_configuration(row))
                frozen = _freeze(row)
                installs.append(AnimationInstall(run, row['trial'], phase, frozen['layer'], frozen['animation'], frozen))
        _require(len(runs) == 10 and set(runs.values()) == set(range(1, 11)), 'incomplete trials')
        _require(completed == set(runs), 'incomplete dismissal capture')
        _require(all(index == len(SCENARIO_EVENTS) for index in event_index.values()), 'incomplete scenario event sequence')
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


# The recovery bundle is pinned independently of any caller-supplied profile.
# Altering a coefficient, instruction range, or evidence source cannot produce
# a new accepted profile. A new build requires a new independently audited bundle.
_RECOVERY_ROOT = Path(__file__).resolve().parents[1]
_RECOVERY_FILES = {
    'research/os_motion/ios26_commit_function_evidence.json': '9f76ea98e22720102c3dc55393fded7f67cdcf768f9bbf3a13c9a8d06554cf4e',
    'research/os_motion/ios26_commit_disassembly.txt': '4c55ccbed4c1d63db4d1934a023abf2c92eb780562db2847fad4104df12c497f',
    'research/os_motion/ios26_function_evidence.json': '50a3fdc13b2dd8c2d5ebdb37253d1bd4ce6b4f5549103dcf7b67a14cba2d7410',
    'research/os_motion/ios26_uikit_attributes_disassembly.txt': 'c7b5995eb72e9ec60161f147b85e0b50bf38bb2adef3df638949b9d88f570a6f',
    'research/os_motion/ios26_uikit_disassembly.txt': 'ea71ef641e756211041da9b2e3e9d0b1f2864243effd6f5089dfe33e72378fea',
    'research/os_motion/ios26_quartzcore_disassembly.txt': 'f365a8023fe6cb5ac04a4ac5cfbfc1e385965eea64b3c849963211786dd94b3a',
}
_OBJECT_ARCHIVE_SHA = '68789a0c5803bf8d6c776399c08a10c710bff2c87ab5ee5b9658699882c17e29'


def _plain(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key: _plain(child) for key, child in value.items()}
    if isinstance(value, (list, tuple)):
        return [_plain(child) for child in value]
    return value


def _canonical(value: Any) -> bytes:
    return (json.dumps(_plain(value), sort_keys=True, indent=2, allow_nan=False) + '\n').encode()


@dataclass(frozen=True)
class OsMotionReport:
    """Immutable OS recovery; an equation is not a promoted window-y profile."""
    data: Mapping[str, Any]

    def to_dict(self) -> dict:
        return _plain(self.data)

    def profile_bytes(self) -> bytes:
        return _canonical(self.data['production_profile'])

    def report_bytes(self) -> bytes:
        return _canonical(self.data)


def _finite(*values: Any) -> None:
    _require(all(type(v) in (int, float) and math.isfinite(v) for v in values), 'nonfinite or untyped solver field')


def spring_response(t: float, *, mass: float, stiffness: float, damping: float,
                    initial_velocity: float = 0, allows_overdamping: bool = False) -> tuple[float, float, float]:
    """q, dq/dt, d2q/dt2 from the literal 23G90 State update/eval path.

    This evaluates a spring at solver-local seconds, without media timing,
    target clamping, completion heuristics, or a window-coordinate claim.
    The allowed-overdamping branch follows the binary's coefficient ordering,
    not the conventional second-order solution; it has no runtime promotion.
    Host libm arithmetic does not claim bit identity with the guest libm/FMA.
    """
    _finite(t, mass, stiffness, damping, initial_velocity)
    _require(t >= 0 and mass > 0 and stiffness > 0 and damping >= 0
             and type(allows_overdamping) is bool, 'invalid spring solver fields')
    omega = math.sqrt(stiffness / mass)
    zeta = damping / (2 * math.sqrt(stiffness * mass))
    if zeta < 1:
        beta = zeta * omega
        wd = omega * math.sqrt(1 - zeta*zeta)
        b = (beta - initial_velocity) / wd
        cosine, sine = math.cos(wd*t), math.sin(wd*t)
        h = cosine + b*sine
        hp = wd*(-sine + b*cosine)
        envelope = math.exp(-beta*t)
        q = 1 - envelope*h
        v = envelope*(beta*h - hp)
        a = envelope*((wd*wd-beta*beta)*h + 2*beta*hp)
    elif zeta > 1 and allows_overdamping:
        beta = zeta * omega
        gamma = omega * math.sqrt(zeta*zeta - 1)
        # State::update +112..+156; State::eval +116..+168.
        fast = (beta + initial_velocity + gamma) / (2*gamma)
        slow = (gamma - beta - initial_velocity) / (2*gamma)
        rfast, rslow = -beta-gamma, gamma-beta
        ef, es = math.exp(rfast*t), math.exp(rslow*t)
        q = 1 - (fast*ef + slow*es)
        v = -(fast*rfast*ef + slow*rslow*es)
        a = -(fast*rfast*rfast*ef + slow*rslow*rslow*es)
    else:
        b = omega - initial_velocity
        envelope = math.exp(-omega*t)
        h = 1 + b*t
        q = 1 - h*envelope
        v = (omega*h-b)*envelope
        a = (2*omega*b-omega*omega*h)*envelope
    if t == 0:
        q = 0.0
    return q, v, a


def uikit_critical_duration(omega: float, initial_velocity: float = 0) -> float:
    """Transcribe _durationOfSpringAnimation's critical approximation.

    Constants are verified from their exact __TEXT constant bytes during
    recovery. This is not a numerical root fit or a tolerance termination.
    """
    _finite(omega, initial_velocity)
    b = omega - initial_velocity
    _require(omega > 0 and b > 0, 'unsupported UIKit duration branch')
    logarithm = math.log(abs(omega * math.exp(-omega/b) * .001 / b))
    u = -1 - logarithm
    _require(u >= 0, 'unsupported UIKit duration approximation domain')
    p = math.sqrt(.5*u) * .3361
    denominator = 1 + (u * -.0042) * math.exp(math.sqrt(u) * -.0201)
    correction = (1 - 1/(1 + p/denominator)) * -5.950609937518595
    return -(b * (logarithm + correction) + omega) / (omega*b)


def animation_local_time(parent_time: float, *, begin_time: float, speed: float, time_offset: float) -> float:
    """Interior active-time mapping with an already resolved parent epoch.

    Zero installation beginTime is the commit sentinel in this cohort. Fill,
    repeat, autoreverse, endpoint handling and ancestor timing are separate
    operations; this helper does not resolve those or fabricate a begin time.
    """
    _finite(parent_time, begin_time, speed, time_offset)
    _require(begin_time != 0, 'unresolved commit-time epoch')
    try:
        stored_speed = struct.unpack('<f',struct.pack('<f',speed))[0]
    except OverflowError as error:
        raise EvidenceError('invalid float32 animation speed') from error
    _finite(stored_speed)
    return (parent_time - begin_time) * stored_speed + time_offset


def interpolate_scalar(from_value: float, to_value: float, progress: float, *, additive_base: float = 0) -> float:
    """Scalar interpolation and addition; never apply this to CATransform3D."""
    _finite(from_value, to_value, progress, additive_base)
    return additive_base + from_value + (to_value - from_value)*progress


def _segments(data: bytes) -> list[tuple[int, int, int, int]]:
    _require(data[:4] == b'\xcf\xfa\xed\xfe', 'unresolved recovery binary Mach-O')
    result = []; offset = 32
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        command, size = struct.unpack_from('<II', data, offset)
        if command == 0x19:
            result.append(struct.unpack_from('<4Q', data, offset+24))
        offset += size
    return result


def _binary_range(data: bytes, address: int, length: int) -> tuple[int, bytes]:
    for vm, _, offset, filesize in _segments(data):
        if vm <= address and address + length <= vm + filesize:
            start = offset + address - vm
            raw = data[start:start+length]
            _require(len(raw) == length, 'incomplete binary function range')
            return start, raw
    raise EvidenceError('unmapped binary function range')


def _function_symbols(data: bytes) -> tuple[list[int], dict[int, str]]:
    """Read actual executable-section nlist symbols, never infer from strings."""
    offset = 32; sections = set(); section_index = 0; symtab = None
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        command, size = struct.unpack_from('<II', data, offset)
        if command == 2:
            symtab = struct.unpack_from('<4I', data, offset+8)
        if command == 0x19:
            for i in range(struct.unpack_from('<I', data, offset+64)[0]):
                section_index += 1
                flags = struct.unpack_from('<I', data, offset+72+i*80+64)[0]
                if flags & 0x80000400:
                    sections.add(section_index)
        offset += size
    _require(symtab is not None, 'unresolved binary function symbols')
    symoff, count, stroff, strsize = symtab; strings = data[stroff:stroff+strsize]; names = {}
    for index in range(count):
        string_index, kind, section, _, address = struct.unpack_from('<IBBHQ', data, symoff+index*16)
        if section in sections and kind & 0xe == 0xe and string_index < strsize:
            end = strings.find(b'\0', string_index)
            _require(end >= 0, 'invalid binary function symbol')
            names[address] = strings[string_index:end].decode('utf8')
    _require(bool(names), 'missing binary executable symbols')
    return sorted(names), names


def _decode_struct(value: Mapping) -> dict:
    _require(isinstance(value, Mapping) and set(value) == {'encoding', 'bytes_base64'}, 'unresolved property endpoint')
    scalars = re.sub(r'\{[^={}]*=', '', value['encoding']).replace('}', '')
    _require(scalars and all(c == 'd' for c in scalars), 'unresolved property coordinate encoding')
    values = struct.unpack('<'+scalars, base64.b64decode(value['bytes_base64'], validate=True))
    _finite(*values)
    return {'encoding': value['encoding'], 'values': list(values), 'bytes_base64': value['bytes_base64']}


def recover_os_motion(animation_records: list[AnimationInstall], binaries: Mapping[str, str | Path]) -> OsMotionReport:
    """Recover only the pinned Task 1/23G90 bundle; no y-trace argument exists.

    Install objects cannot prove coherent post-commit geometry or completion.
    The report therefore preserves unresolved production phases even though
    the scalar spring and its construction path are independently recovered.
    """
    _require(isinstance(binaries, Mapping) and set(binaries) == {'UIKitCore', 'QuartzCore'}, 'missing exact OS binary set')
    for relative, digest in _RECOVERY_FILES.items():
        _require(_sha(_read(_RECOVERY_ROOT/relative)) == digest, 'recovery evidence hash mismatch: '+relative)
    static = _json(_read(_RECOVERY_ROOT/'research/os_motion/ios26_function_evidence.json'))
    commit_static = _json(_read(_RECOVERY_ROOT/'research/os_motion/ios26_commit_function_evidence.json'))
    _schema(commit_static, ('schema_version','images','functions'), context='commit function bundle')
    _require(commit_static['schema_version'] == 1 and commit_static['images'] == static['images'], 'commit function image identity mismatch')
    _require(not (set(commit_static['functions']) & set(static['functions'])), 'duplicate commit function evidence')
    static['functions'].update(commit_static['functions'])
    binary_data = {}; symbols = {}
    for name, declared in static['images'].items():
        raw = _read(Path(binaries[name]))
        _require(_sha(raw) == declared['sha256'] and declared['uuid'] in _binary_uuids(raw), 'exact guest binary identity mismatch: '+name)
        binary_data[name] = raw; symbols[name] = _function_symbols(raw)
    for function in static['functions'].values():
        name = function['image']; address = int(function['address'],16)
        starts,names = symbols[name]
        index = bisect.bisect_left(starts,address)
        _require(index+1 < len(starts) and starts[index] == address
                 and starts[index+1]-address == function['length'], 'binary function nlist range mismatch')
        _require(address-int(static['images'][name]['vm_base'],16) == function['image_offset'],
                 'binary function image offset mismatch')
        offset, raw = _binary_range(binary_data[name], address, function['length'])
        _require(offset == function['file_offset'] and _sha(raw) == function['sha256'], 'binary function hash/range mismatch')
        _require(symbols[name][1].get(address) == function['name'], 'binary function symbol mismatch')
    constants = {}
    for label, item in static['constants'].items():
        offset, raw = _binary_range(binary_data['UIKitCore'], int(item['address'],16), 8)
        _require(offset == item['file_offset'] and raw.hex() == item['bits_hex'], 'binary constant mismatch')
        constants[label] = struct.unpack('<d',raw)[0]
    evidence = _RECOVERY_ROOT/'artifacts/native/os_motion_ios26_vphone/animation-objects.jsonl.gz'
    _require(_sha(_read(evidence)) == _OBJECT_ARCHIVE_SHA, 'wrong authenticated object cohort archive')
    trusted = load_animation_objects(evidence)
    _require(type(animation_records) in (list, tuple) and len(animation_records) == len(trusted)
             and all(type(got) is AnimationInstall and got == expected for got, expected in zip(animation_records,trusted)),
             'input is not the authenticated complete object cohort')
    manifest = _json(_read(evidence.parent/'manifest.json'))
    for name,declared in static['images'].items():
        matching = [image for image in manifest['images'] if image['runtime_path'] == declared['runtime_path']]
        _require(len(matching) == 1 and all(matching[0][key] == declared[key] for key in ('uuid','sha256')),
                 'OS binary manifest identity mismatch: '+name)
    omega = constants['two_pi'] / constants['response']
    stiffness = omega*omega; damping = 2*math.sqrt(stiffness)
    duration = uikit_critical_duration(omega)
    _require((omega,stiffness,damping,duration) == (18.257418582058744,333.3333332805039,36.51483716411749,.5058237871186482),
             'recovered binary conversion/duration mismatch')
    # Symbolicate every captured UIKit/Quartz return address from exact nlists.
    frame_map = {}
    for record in trusted:
        for frame in record.record['backtrace']:
            name = Path(frame['image']).name
            if name not in symbols:
                continue
            address = int(static['images'][name]['vm_base'],16) + frame['image_offset']
            starts,names = symbols[name]; index = bisect.bisect_right(starts,address)-1
            key = name+':'+hex(frame['image_offset'])
            if key in frame_map:
                continue
            if index < 0 or index+1 >= len(starts):
                frame_map[key] = {'status':'unresolved','image_offset':frame['image_offset']}
                continue
            start,end = starts[index:index+2]
            _,raw = _binary_range(binary_data[name],start,end-start)
            frame_map[key] = {'status':'resolved_executable_symbol','name':names[start],
                              'address':hex(address),'function_address':hex(start),
                              'function_length':end-start,'function_sha256':_sha(raw)}
    roots = [r for r in trusted if r.layer['class']=='_UIMultiLayer' and r.animation['key_path'] in ('position','bounds.size','transform')]
    _require(roots and all(r.eligible_for_math_candidate for r in roots), 'unresolved root animation fields')
    solver_fields = ('mass','stiffness','damping','initial_velocity','allows_overdamping','settling_duration')
    timing_fields = ('duration','begin_time','time_offset','speed','timing_function','repeat_count','repeat_duration',
                     'autoreverses','fill_mode','additive','cumulative','removed_on_completion')
    detent = next(r for r in roots if r.phase=='medium_to_large' and r.animation['key_path']=='position')
    transition = next(r for r in roots if r.phase=='dismissal' and r.animation['key_path']=='position')
    def family(record):
        result = {key:record.animation['spring'][key] for key in solver_fields}
        result.update({key:record.animation[key] for key in timing_fields})
        w = math.sqrt(result['stiffness']/result['mass'])
        result.update(omega=w, nominal_zeta=result['damping']/(2*math.sqrt(result['stiffness']*result['mass'])),
                      solver_branch='critical', equation='q(t)=1-(1+omega*t)*exp(-omega*t)',
                      initial_velocity_policy='zero_only', status='recovered_scalar_not_promoted',
                      time_domain='resolved animation-local seconds', terminal_policy='unresolved_retained_fill_and_UIKit_cleanup')
        return _plain(result)
    detent_family, transition_family = family(detent), family(transition)
    _require(tuple(detent.animation['spring'][k] for k in ('mass','stiffness','damping','initial_velocity','allows_overdamping'))
             == (1,stiffness,damping,0,False) and detent.animation['duration']==duration, 'binary/object detent spring mismatch')
    # Compare all flags exactly, not averages and not trajectory similarity.
    reuse = {}
    for phase in ('fixed320_to_medium','medium_to_large','large_to_medium'):
        selected = [r for r in roots if r.phase==phase]
        expected = {key:detent.animation[key] for key in timing_fields}
        _require(all(dict(r.animation['spring'])==dict(detent.animation['spring'])
                     and all(r.animation[k]==v for k,v in expected.items()) for r in selected), 'detent solver configuration reuse mismatch')
        reuse[phase] = {'root_install_count':len(selected),'solver_and_timing_identical':True,
                        'coordinate_properties':sorted({r.animation['key_path'] for r in selected}),
                        'distance_scaling_promoted':False}
    reason = ['commit_time_begin_epoch_missing_at_install', 'coherent_post_transaction_model_state_missing',
              'additive_CATransform3D_interpolation_and_composition_unresolved', 'UIKit_explicit_cleanup_and_retained_fill_terminal_unresolved',
              'target_layer_to_presented_sheet_view_ownership_not_captured']
    phases = {}
    for phase in PHASES:
        selected = [r for r in roots if r.phase==phase]
        phases[phase] = {'status':'unresolved','reasons':reason,
                         'solver_family':'detent' if phase in reuse else 'presentation_dismissal_observed',
                         'representative_trial':1,
                         'installation_references':[{'run_id':r.run_id,'trial':r.trial,'sequence':r.record['seq'],
                                                     'layer_id':r.layer['id'],'key_path':r.animation['key_path']} for r in selected],
                         'objects':[{'run_id':r.run_id,'trial':r.trial,'sequence':r.record['seq'],'layer_id':r.layer['id'],
                                     'key_path':r.animation['key_path'], 'key':r.record['key'],
                                     'from_value':_decode_struct(r.animation['from_value']), 'to_value':_decode_struct(r.animation['to_value']),
                                     'layer_state_at_install':_plain(r.layer['model_state']),
                                     'ancestry_ids':[n['id'] for n in r.layer['ancestry']],
                                     'owner_frames':[name+':'+hex(f['image_offset']) for f in r.record['backtrace']
                                                     if (name:=Path(f['image']).name) in symbols]}
                                    for r in selected if r.trial==1]}
    hashes = dict(_RECOVERY_FILES)
    hashes.update(object_archive=_OBJECT_ARCHIVE_SHA,object_raw=manifest['raw_sha256'],
                  object_manifest=_sha(_read(evidence.parent/'manifest.json')),analysis_source=_sha(_read(Path(__file__))))
    scope = {key:manifest[key] for key in ('os','device','device_geometry','environment','configuration','scenario_id','resolved_detents')}
    images = {name:{key:value for key,value in item.items() if key!='path'} for name,item in static['images'].items()}
    commit_composition = {'status':'blocked_unsealed_runtime_cohort_excluded', 'runtime_object_cohort_included':False,
                          'promoted_phases':[], 'available_static_functions':sorted(commit_static['functions']),
                          'remaining_jobs':['private_additive_CATransform3D_interpolation_and_order',
                                            'exact_sheet_view_and_controller_ownership',
                                            'guaranteed_coherent_post_transaction_model_boundary'],
                          'follow_on':'implement_Dart_only_after_OS_recovery_then_run_post_freeze_tests',
                          'no_fitted_or_visual_curves':True}
    profile = {'schema_version':1,'source_kind':'authenticated_os_equation_recovery','id':'ios26_23G90_vphone_page',
               'status':'unresolved','scope':scope,'profiles':[],
               'unresolved_phases':{phase:{'status':'unresolved','reasons':reason} for phase in PHASES},
               'unsupported':['interruption','drag_release','keyboard_rebase','arbitrary_custom_detents','other_runtime_or_configuration'],
               'source_hashes':hashes,'binaries':images,'function_evidence':static['functions'],
               'commit_composition':commit_composition}
    data = {'schema_version':1,'source_kind':'authenticated_os_binary_and_install_objects','install_count':len(trusted),
            'status':'recovered_equations_with_unresolved_window_y_profiles','scope':scope,
            'source_hashes':hashes,'binaries':images,'function_evidence':static['functions'],'binary_constants':static['constants'],
            'uikit_construction':{'detent_owner':'-[UISheetPresentationController _animateChanges:completion:]',
                                 'animator':'_UISheetAnimateWithCompletion','high_speed':False,'damping_ratio':1,
                                 'response':constants['response'],'nominal_ui_duration':constants['ui_duration'],
                                 'exact_ca_duration':duration,'timing_fields_source':'complete_install_object'},
            'solver_families':{'detent':detent_family,'presentation_dismissal_observed':transition_family},
            'solver_semantics':{'branch_selector':'zeta<1 under; zeta>1 and allowsOverdamping true over; otherwise critical',
                                'critical':'q=1-(1+(omega-v0)*t)*exp(-omega*t)',
                                'critical_zero_velocity_derivatives':['omega^2*t*exp(-omega*t)','omega^2*(1-omega*t)*exp(-omega*t)'],
                                'underdamped':'beta=zeta*omega; wd=omega*sqrt(1-zeta^2); q=1-exp(-beta*t)*(cos(wd*t)+(beta-v0)/wd*sin(wd*t))',
                                'allowed_overdamped_static':'gamma=omega*sqrt(zeta^2-1); A=(beta+v0+gamma)/(2*gamma); B=(gamma-beta-v0)/(2*gamma); q=1-A*exp(-(beta+gamma)*t)-B*exp((gamma-beta)*t)',
                                'allowed_overdamped_status':'static_instruction_transcription_only_no_runtime_candidate',
                                'local_time':'active=(parent-begin)*float32(speed)+timeOffset; then repeat/autoreverse; normalized=local/duration; spring eval uses normalized*duration',
                                'coordinate_scalar':'base+from+(to-from)*q; CATransform3D is unresolved',
                                'duration_is_not_settling_duration':True,'target_clamp_proven':False,
                                'numeric_identity':'host_libm_mathematical_conformance_only_guest_FMA_and_transcendentals_unverified'},
            'backtrace_resolution':frame_map,'detent_configuration_reuse':reuse,'phases':phases,
            'commit_composition':commit_composition,'production_profile':profile}
    return OsMotionReport(_freeze(data))


def validate_motion_manifest(path: str | Path, animation_records: list[AnimationInstall], binaries: Mapping[str, str | Path]) -> None:
    """Reject all edits, omissions, extra sources or scope changes by regeneration."""
    expected = recover_os_motion(animation_records,binaries).profile_bytes()
    _require(_read(Path(path)) == expected, 'motion manifest is not canonical OS recovery')


@dataclass(frozen=True)
class AnimationCommit:
    run_id: str
    install_id: str
    pre_forward: Mapping
    post_forward: Mapping
    next_runloop: Mapping
    cleanup: tuple[Mapping, ...]


_COMMIT_FIELDS = COMMON_FIELDS | set(('trial phase transaction_time layer key animation transaction backtrace '
    'install_id stage installed_animation owner_backtrace commit_epoch_status installation_status observation_boundary').split())


def pair_commit_objects(rows: list[dict]) -> tuple[AnimationCommit, ...]:
    """Pair discrete snapshots. This structural helper confers no provenance."""
    grouped = {}; identities = {}; addresses = {}; previous = {}
    for row in rows:
        _schema(row, _COMMIT_FIELDS, context='commit snapshot')
        _metadata_types(row, strings=('type', 'run_id', 'phase', 'install_id', 'stage', 'commit_epoch_status',
                                      'installation_status', 'observation_boundary'), nullable_strings=('key',),
                        integers=('schema_version', 'seq', 't_ns', 'trial'), numbers=('transaction_time',), context='commit snapshot')
        _require(row['schema_version'] == 1 and row['type'] in ('animation_commit', 'animation_cleanup'), 'wrong commit snapshot type')
        run = row['run_id']; stage = row['stage']
        _require(row['seq'] > previous.get(run, -1), 'duplicate or unordered commit sequence'); previous[run] = row['seq']
        _require(row['phase'] in PHASES, 'unknown commit phase')
        _require(row['installation_status'] in ('current', 'superseded', 'unresolved_nil_key'), 'unknown installation state')
        _require(row['commit_epoch_status'] == 'unresolved_next_runloop_is_not_commit', 'unauthenticated commit epoch assertion')
        _require(row['observation_boundary'] == ('main_queue_async_no_flush' if stage == 'next_runloop' else 'synchronous_call_boundary'), 'unknown observation boundary')
        layer = row['layer']
        _schema(layer, ('id', 'address', 'class', 'parent_id', 'model_state', 'presentation_state', 'ancestry', 'timing', 'delegate'), context='commit layer')
        _metadata_types(layer, strings=('id', 'address', 'class'), nullable_strings=('parent_id',), context='commit layer')
        ancestry = layer['ancestry']
        _require(type(ancestry) is list and layer['parent_id'] == (ancestry[0]['id'] if ancestry else None), 'missing ordered ancestor')
        chain = [layer] + ancestry
        _require(len({node['id'] for node in chain}) == len(chain), 'duplicate ancestor identity')
        for node in chain:
            if node is not layer:
                _schema(node, ('id', 'address', 'class', 'model_state', 'presentation_state', 'timing'), context='commit ancestor')
            _metadata_types(node, strings=('id', 'address', 'class'), context='commit identity')
            _require(bool(re.fullmatch('0x[0-9a-f]+', node['address'])), 'invalid commit layer address')
            identity = (run, node['id']); stable = (node['address'], node['class']); address = (run, node['address'])
            _require(identity not in identities or identities[identity] == stable, 'commit layer identity changed')
            _require(address not in addresses or addresses[address] == node['id'], 'commit layer address alias')
            identities[identity] = stable; addresses[address] = node['id']
            _layer_state(node['model_state'])
            _require(node['presentation_state'] is None, 'forbidden presentation polling')
            _schema(node['timing'], ('begin_time', 'speed', 'time_offset', 'local_media_time'), context='layer timing')
            _metadata_types(node['timing'], numbers=('begin_time', 'speed', 'time_offset', 'local_media_time'), context='layer timing')
        if layer['delegate'] is not None:
            _schema(layer['delegate'], ('class', 'address'), context='layer delegate')
            _metadata_types(layer['delegate'], strings=('class', 'address'), context='layer delegate')
        key = (run, row['install_id']); grouped.setdefault(key, []).append(row)
    result = []
    for (run, identity), snapshots in grouped.items():
        stages = {}; cleanup = []
        reference = snapshots[0]
        for row in snapshots:
            _require(all(row[k] == reference[k] for k in ('trial', 'phase', 'key', 'animation', 'owner_backtrace')), 'commit pair configuration mismatch')
            _require(all(row['layer'][k] == reference['layer'][k] for k in ('id', 'address', 'class')), 'commit pair layer mismatch')
            if row['type'] == 'animation_commit':
                _require(row['stage'] in ('pre_forward', 'post_forward', 'next_runloop') and row['stage'] not in stages, 'duplicate commit boundary')
                stages[row['stage']] = row
            else:
                _require(row['stage'] in ('pre_remove', 'post_remove', 'pre_remove_all', 'post_remove_all') or
                         row['stage'] in ('checkpoint.present_completed', 'checkpoint.before_detent_request',
                                          'checkpoint.before_dismiss_request', 'checkpoint.dismiss_completed', 'checkpoint.terminal'), 'unknown cleanup boundary')
                cleanup.append(row)
        _require(set(stages) == {'pre_forward', 'post_forward', 'next_runloop'}, 'missing commit boundary')
        ordered = [stages[s] for s in ('pre_forward', 'post_forward', 'next_runloop')]
        _require(ordered[0]['seq'] < ordered[1]['seq'] < ordered[2]['seq'], 'unordered commit boundary')
        _require(all(a['t_ns'] <= b['t_ns'] for a,b in zip(ordered, ordered[1:])), 'nonmonotonic commit time')
        for snapshot in ordered[1:]:
            installed = snapshot['installed_animation']
            if installed is not None and snapshot['installation_status'] == 'current':
                # Core Animation assigns beginTime and model property state can
                # change between observations. Construction fields must not.
                ignored = {'begin_time', 'model_value', 'current_value'}
                _require({k:_plain(v) for k,v in installed.items() if k not in ignored} ==
                         {k:_plain(v) for k,v in reference['animation'].items() if k not in ignored}, 'installed copy construction mismatch')
        pending = None
        for row in cleanup:
            if row['stage'] in ('pre_remove', 'pre_remove_all'):
                _require(pending is None, 'duplicate removal pre-boundary'); pending = row['stage']
            elif row['stage'] in ('post_remove', 'post_remove_all'):
                _require(pending == row['stage'].replace('post_', 'pre_') and row['installed_animation'] is None, 'unresolved or incoherent removal boundary')
                pending = None
        _require(pending is None, 'missing removal post-boundary')
        result.append(AnimationCommit(run, identity, *(_freeze(s) for s in ordered), tuple(_freeze(s) for s in cleanup)))
    _require(bool(result), 'missing commit pairs')
    return tuple(result)


def committed_animation_local_time(pair: AnimationCommit, media_time: float) -> float:
    """Use the assigned object's epoch, never the observation timestamp.

    Layer::commit_animations +516/+696 in the authenticated 23G90 function
    writes setBeginTime after mapping commit-layer timing. Zero remains
    unresolved. A main-queue observation is not itself the commit epoch.
    """
    row = pair.next_runloop; a = row['installed_animation']
    _require(a is not None and row['installation_status'] == 'current' and
             type(a['begin_time']) in (int,float) and a['begin_time'] != 0, 'unresolved installed commit epoch')
    _finite(media_time)
    time = media_time
    for node in reversed([row['layer']] + list(row['layer']['ancestry'])):
        timing = node['timing']; _finite(timing['begin_time'],timing['speed'],timing['time_offset'])
        speed = struct.unpack('<f',struct.pack('<f',timing['speed']))[0]
        time = (time-timing['begin_time'])*speed+timing['time_offset']
    return animation_local_time(time,begin_time=a['begin_time'],speed=a['speed'],time_offset=a['time_offset'])


def commit_scalar_endpoints(pair: AnimationCommit) -> tuple[float,float,float]:
    """Explicit scalar endpoints with final model fallback; unknown starts reject."""
    a = pair.next_runloop['installed_animation']
    _require(a is not None and pair.next_runloop['installation_status'] == 'current', 'unresolved endpoint installed copy')
    start = a['from_value']; target = a['to_value']; model = a['model_value']
    _require(a['by_value'] is None and start is not None, 'unresolved scalar endpoint construction')
    if target is None: target = model
    _require(all(type(v) in (int,float) and math.isfinite(v) for v in (start,target,model)), 'nonfinite or nonscalar endpoint')
    _require(type(a['additive']) is bool, 'unresolved endpoint additive flag')
    return start,target,model if a['additive'] else 0


def commit_cleanup_state(pair: AnimationCommit) -> str:
    if any(row['stage'] in ('post_remove', 'post_remove_all') for row in pair.cleanup):
        return 'explicit_removal_observed'
    if pair.cleanup and pair.cleanup[-1]['installed_animation'] is not None:
        return 'installed_copy_persists_at_last_checkpoint'
    return 'unresolved_automatic_or_unobserved_cleanup'


def _affine_matrix(matrix) -> tuple[float, float, float, float, float, float]:
    _require(len(matrix) == 16, 'incomplete affine matrix'); _finite(*matrix)
    _require(all(matrix[i] == expected for i,expected in {2:0,3:0,6:0,7:0,8:0,9:0,10:1,11:0,14:0,15:1}.items()), 'nonaffine or unresolved 3D path')
    return matrix[0],matrix[1],matrix[4],matrix[5],matrix[12],matrix[13]


def affine_point_to_root(point, layer_path: list[Mapping]) -> tuple[tuple[float,float], tuple[tuple[float,float],tuple[float,float]]]:
    """Checked mathematical affine composition, not a promoted UIKit mapping.

    Path order is target to root. Coordinates are each layer's bounds space.
    Private additive CATransform3D interpolation and controller identity are
    intentionally outside this utility and remain recovery prerequisites.
    """
    _require(bool(layer_path) and len({n['id'] for n in layer_path}) == len(layer_path), 'missing or duplicate ancestor path')
    _require(layer_path[-1]['parent_id'] is None, 'missing root ancestor')
    for i,node in enumerate(layer_path):
        _require(node['parent_id'] == (layer_path[i+1]['id'] if i+1<len(layer_path) else None), 'ancestor order mismatch')
        _layer_state(_plain(node['model_state'])); state = node['model_state']
        _require(not state['geometry_flipped'] and state['anchor_point_z'] == 0 and state['z_position'] == 0, 'unresolved flipped or 3D ancestor')
        _finite(*state['position'],*state['bounds'],*state['anchor_point'])
        _affine_matrix(state['transform']); _affine_matrix(state['sublayer_transform'])
    _finite(*point); x,y = point; j = ((1.,0.),(0.,1.))
    def apply(matrix, px, py, jac):
        a,b,c,d,tx,ty = _affine_matrix(matrix)
        return a*px+c*py+tx,b*px+d*py+ty,((a*jac[0][0]+c*jac[1][0],a*jac[0][1]+c*jac[1][1]),
                                                        (b*jac[0][0]+d*jac[1][0],b*jac[0][1]+d*jac[1][1]))
    def anchor(state):
        b = state['bounds']; a = state['anchor_point']; return b[0]+a[0]*b[2],b[1]+a[1]*b[3]
    for child,parent in zip(layer_path,layer_path[1:]):
        state = child['model_state']; ax,ay = anchor(state)
        x,y,j = apply(state['transform'],x-ax,y-ay,j)
        x += state['position'][0]; y += state['position'][1]
        ps = parent['model_state']; ax,ay = anchor(ps)
        x,y,j = apply(ps['sublayer_transform'],x-ax,y-ay,j)
        x += ax; y += ay
    return (x,y),j


def load_commit_objects(path: str | Path) -> tuple[AnimationCommit, ...]:
    """Authenticate complete object-only run provenance before pairing."""
    path = Path(path); root = path.parent
    try:
        manifest = _json(_read(root/'manifest.json')); _manifest_schema(manifest); _walk(manifest)
        _require(manifest['evidence_kind'] == 'runtime_animation_commit' and manifest['capture_mode'] == 'animation_commit_objects', 'wrong commit evidence kind')
        _require(manifest['os'] == OS and manifest['device'] == DEVICE and manifest['trial_count'] == 10
                 and manifest['scenario_id'] == 'native.geometry.smoke' and manifest['records_file'] == path.name, 'wrong commit cohort scope')
        packed = _read(path); _require(_sha(packed) == manifest['compressed_sha256'], 'commit compressed hash mismatch')
        raw = gzip.decompress(packed); _require(_sha(raw) == manifest['raw_sha256'], 'commit raw hash mismatch')
        images = _authenticate_files(root,manifest)
        lines = raw.splitlines(keepends=True); rows = [_json(line) for line in lines]
        declarations = {r['run_id']:r for r in manifest['runs']}
        _require(len(declarations) == len(manifest['runs']) == 10 and {r['trial'] for r in declarations.values()} == set(range(1,11)), 'missing commit trials')
        runs = {}; previous = {}; times = {}; raw_runs = {}; phase = {}; indices = {}; completed = set(); snapshots = []
        for line,row in zip(lines,rows):
            _walk(row); run = row['run_id']; kind = row['type']
            _require(run in declarations and row['seq'] == previous.get(run,0), 'invalid commit run sequence')
            previous[run] = row['seq']+1; raw_runs.setdefault(run,[]).append(line)
            _require(type(row['t_ns']) is int and row['t_ns'] >= times.get(run,0), 'nonmonotonic commit run time'); times[run] = row['t_ns']
            if kind in ('session','event'):
                _record_schema(row)
            if kind == 'session':
                _require(run not in runs and row['capture_mode'] == manifest['capture_mode'] and row['scenario_id'] == manifest['scenario_id'] and row['os'] == OS, 'wrong commit session')
                request = manifest['capture_request']
                _require(row['provenance'] == {'attempt_id':request['attempt_id'],'role':request['role'],'native_source_revision':manifest['native_source_revision']}, 'commit source provenance mismatch')
                _require(row['device'] == manifest['device_geometry'] and row['environment'] == manifest['environment'], 'commit geometry/environment mismatch')
                _require({k:v for k,v in row['configuration'].items() if k!='trial'} == manifest['configuration'] and row['configuration']['trial'] == declarations[run]['trial'], 'commit configuration mismatch')
                runs[run] = row['configuration']['trial']; indices[run] = 0; phase[run] = None
            elif kind == 'event':
                _require(run in runs, 'event before commit session')
                name = row['name']
                if name == 'detent.resolved':
                    _require(run not in completed and indices[run] > 0 and row['data'] == manifest['resolved_detents'], 'commit detent metadata mismatch')
                elif name == 'batch.completed':
                    _require(run in completed and runs[run] == 10 and row['data'] == {'trials':10}, 'invalid commit batch boundary')
                else:
                    i = indices[run]; _require(i < len(SCENARIO_EVENTS) and (name,row['data']) == SCENARIO_EVENTS[i], 'commit scenario boundary mismatch')
                    indices[run] += 1
                    if i in (0,2,3,4,5): phase[run] = {0:'presentation',2:'fixed320_to_medium',3:'medium_to_large',4:'large_to_medium',5:'dismissal'}[i]
                    if name == 'dismiss.completed': completed.add(run)
            elif kind in ('animation_commit','animation_cleanup'):
                _require(run in runs and run not in completed and row['trial'] == runs[run], 'snapshot outside commit run lifetime')
                if kind == 'animation_commit' and row['stage'] == 'pre_forward': _require(row['phase'] == phase[run], 'commit phase/event mismatch')
                _animation(row['animation'])
                if row['installed_animation'] is not None: _animation(row['installed_animation'])
                _schema(row['transaction'], ('duration','disable_actions','timing_function'), context='commit transaction')
                _require(_number(row['transaction']['duration']) and type(row['transaction']['disable_actions']) is bool, 'invalid commit transaction')
                _timing_schema(row['transaction']['timing_function'])
                for frames in (row['backtrace'],row['owner_backtrace']):
                    _require(type(frames) is list and bool(frames), 'missing commit backtrace')
                    for frame in frames:
                        _schema(frame, ('address','image','image_uuid','image_base','image_offset','symbol','symbol_address'), context='commit backtrace')
                        _metadata_types(frame,strings=('address','image','image_uuid','image_base'),nullable_strings=('symbol','symbol_address'),integers=('image_offset',),context='commit backtrace')
                        identity = (frame['image'],frame['image_uuid']); _require(identity in images, 'unresolved commit backtrace image')
                        offset = frame['image_offset']; ranges = images[identity]['executable_ranges']
                        _require(offset >= 0 and int(frame['address'],16)-int(frame['image_base'],16) == offset and any(a<=offset<b for a,b in ranges), 'commit backtrace outside executable mapping')
                        if frame['symbol_address'] is not None:
                            symbol = int(frame['symbol_address'],16)-int(frame['image_base'],16)
                            _require(any(a<=symbol<b for a,b in ranges), 'commit symbol outside executable mapping')
                snapshots.append(row)
            else: raise EvidenceError('forbidden commit record type')
        _require(set(runs) == completed == set(declarations) and all(i == len(SCENARIO_EVENTS) for i in indices.values()), 'incomplete commit trial completion')
        pairs = pair_commit_objects(snapshots)
        _require(len(pairs) == manifest['record_count'], 'commit pair count mismatch')
        for run,declared in declarations.items():
            _require(_sha(b''.join(raw_runs[run])) == declared['raw_sha256'], 'commit run hash mismatch')
            selected = [p for p in pairs if p.run_id == run]
            _require(len(selected) == declared['install_count'] and {p.pre_forward['phase'] for p in selected} == set(PHASES), 'commit run pair/phase count mismatch')
        return pairs
    except (KeyError,TypeError,ValueError,IndexError,OSError,EOFError) as error:
        if isinstance(error,EvidenceError): raise
        raise EvidenceError('malformed commit evidence: '+str(error)) from error
