"""Exact-scope validation for literal environment fixtures, never runtime acceptance."""
import math


IDENTITY_KEYS = (
    'os_build', 'device_model', 'runtime_kind', 'orientation',
    'horizontal_size_class', 'vertical_size_class', 'safe_area',
)


def _number(value, minimum=-math.inf):
    return type(value) in (int, float) and math.isfinite(value) and value >= minimum


def _text(value):
    return isinstance(value, str) and bool(value.strip())


def _rect(value):
    return (isinstance(value, dict) and set(value) == {'x', 'y', 'width', 'height'} and
            _number(value['x']) and _number(value['y']) and
            _number(value['width'], 0) and _number(value['height'], 0))


def _identity(value):
    if not isinstance(value, dict) or set(value) != set(IDENTITY_KEYS):
        return False
    safe_area = value['safe_area']
    return (
        _text(value['os_build']) and _text(value['device_model']) and
        value['runtime_kind'] in ('simulator', 'virtual_device', 'physical_device') and
        value['orientation'] in ('portrait', 'portrait_upside_down', 'landscape') and
        value['horizontal_size_class'] in ('compact', 'regular') and
        value['vertical_size_class'] in ('compact', 'regular') and
        isinstance(safe_area, dict) and set(safe_area) == {'top', 'left', 'bottom', 'right'} and
        all(_number(safe_area[edge], 0) for edge in safe_area)
    )


def _configured(value):
    return (isinstance(value, dict) and set(value) == {
        'presentation_style', 'preferred_content_size', 'edge_attached_in_compact_height',
        'width_follows_preferred_content_size', 'source_anchor',
    } and value['presentation_style'] in ('page', 'form') and
            isinstance(value['preferred_content_size'], dict) and
            set(value['preferred_content_size']) == {'width', 'height'} and
            _number(value['preferred_content_size']['width'], 0) and _number(value['preferred_content_size']['height'], 0) and
            type(value['edge_attached_in_compact_height']) is bool and
            type(value['width_follows_preferred_content_size']) is bool and _rect(value['source_anchor']))


def _resolved(value, configured):
    if not isinstance(value, dict) or set(value) != {'presentation_style', 'preferred_content_size', 'source_anchor', 'placement', 'source'}:
        return False
    size = value['preferred_content_size']
    placement = value['placement']
    return (
        value['presentation_style'] in ('page', 'form') and
        isinstance(size, dict) and set(size) == {'width', 'height'} and
        _number(size['width'], 0) and _number(size['height'], 0) and
        _rect(value['source_anchor']) and
        value['source'] == 'public_runtime_observation' and
        isinstance(placement, dict) and set(placement) == {'value', 'availability'} and
        placement['availability'] == 'observed_supported' and
        placement['value'] in ('top', 'bottom', 'leading', 'trailing')
    )


def _record(row):
    if not isinstance(row, dict) or set(row) != {'schema_version', 'evidence_kind', 'observation_id', 'identity', 'configured', 'resolved'}:
        return False
    if row['schema_version'] != 1 or row['evidence_kind'] not in ('fixture', 'runtime_observation') or not _text(row['observation_id']) or not _identity(row['identity']) or not _configured(row['configured']):
        return False
    return _resolved(row['resolved'], row['configured'])


def validate_environment_fixture(rows):
    """Qualify only an exact literal fixture scope; do not accept a capability."""
    if not isinstance(rows, list) or not rows or not all(_record(row) for row in rows):
        return {'qualified': False, 'reason': 'invalid_environment_fixture'}
    first = rows[0]
    scope = {key: first[key] for key in ('identity', 'configured', 'resolved')}
    if any({key: row[key] for key in scope} != scope for row in rows):
        return {'qualified': False, 'reason': 'mixed_or_extrapolated_environment'}
    if len({row['observation_id'] for row in rows}) != len(rows):
        return {'qualified': False, 'reason': 'duplicate_observation_id'}
    return {
        'qualified': True,
        'proof_layer': 'literal_fixture_contract_only',
        'native_capability_accepted': False,
        'qualified_scope': scope,
    }
