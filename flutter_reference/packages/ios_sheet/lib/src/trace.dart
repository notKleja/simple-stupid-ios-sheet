import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'comparison_contract.dart';

@immutable
class IosSheetFrame {
  const IosSheetFrame({
    required this.metrics,
    required this.state,
    this.unavailable = const {},
    this.implementationProvenance = const {},
  });
  final Map<String, num?> metrics;
  final Map<String, Object?> state;
  final Map<String, String> unavailable;
  final Map<String, Object?> implementationProvenance;
}

/// Trace v1 adapter. The caller supplies actual device/OS metadata and chooses
/// the destination; this package never fabricates platform identifiers.
///
/// Stopwatch samples use one monotonic clock with microsecond precision,
/// converted to integer nanoseconds. Display/input receipt uses that same
/// clock. Original platform timestamps can be passed in event data separately.
class IosSheetTraceRecorder {
  IosSheetTraceRecorder({
    required this.runId,
    required String scenarioId,
    required this.sink,
    required Map<String, Object?> os,
    required Map<String, Object?> device,
    required Map<String, Object?> environment,
    required Map<String, Object?> configuration,
    String evidenceKind = 'runtime',
    Map<String, Object?> implementationProvenance = const {},
  }) {
    _clock.start();
    _write('session', {
      'scenario_id': scenarioId,
      'native_contract_version': 2,
      'implementation': 'flutter',
      'evidence_kind': evidenceKind,
      'os': os,
      'device': device,
      'environment': environment,
      'configuration': canonicalIosSheetConfiguration(configuration),
      'provenance': {
        'clock': {'source': 'Dart Stopwatch', 'precision_ns': 1000},
        'implementation': implementationProvenance,
      },
    });
  }

  final String runId;
  final ValueChanged<String> sink;
  final Stopwatch _clock = Stopwatch();
  int _sequence = 0;

  void event(String name, [Map<String, Object?> data = const {}]) =>
      eventWithProvenance(name, data: data);

  void eventWithProvenance(
    String name, {
    Map<String, Object?> data = const {},
    Map<String, Object?> implementationProvenance = const {},
  }) {
    final canonical = Map<String, Object?>.of(data);
    for (final key in ['target', 'selected']) {
      if (canonical[key] is String) {
        canonical[key] = canonicalIosDetentIdentifier(canonical[key] as String);
      }
    }
    _write('event', {
      'name': name,
      'data': canonical,
      'terminal': name == 'dismiss.completed' || name == 'run.error',
      if (!mapEquals(canonical, data)) 'raw_event_data': data,
      if (implementationProvenance.isNotEmpty)
        'provenance': implementationProvenance,
    });
  }

  void frame(IosSheetFrame frame) {
    final state = Map<String, Object?>.of(frame.state);
    final raw = <String, Object?>{};
    for (final key in ['selected_detent', 'target_detent']) {
      if (state[key] is String) {
        raw[key] = state[key];
        state[key] = canonicalIosDetentIdentifier(state[key] as String);
      }
    }
    _write('frame', {
      'metrics': frame.metrics,
      'state': state,
      if (raw.isNotEmpty) 'raw_detent_identifiers': raw,
      if (frame.implementationProvenance.isNotEmpty)
        'provenance': frame.implementationProvenance,
      if (frame.unavailable.isNotEmpty) 'unavailable': frame.unavailable,
    });
  }

  void _write(String type, Map<String, Object?> payload) {
    sink(
      '${jsonEncode({'schema_version': 1, 'type': type, 'run_id': runId, 'seq': _sequence++, 't_ns': _clock.elapsedMicroseconds * 1000, ...payload})}\n',
    );
  }
}
