import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
class IosSheetFrame {
  const IosSheetFrame({
    required this.metrics,
    required this.state,
    this.unavailable = const {},
  });
  final Map<String, num?> metrics;
  final Map<String, Object?> state;
  final Map<String, String> unavailable;
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
  }) {
    _clock.start();
    _write('session', {
      'scenario_id': scenarioId,
      'implementation': 'flutter',
      'evidence_kind': evidenceKind,
      'os': os,
      'device': device,
      'environment': environment,
      'configuration': configuration,
      'clock': {'source': 'Dart Stopwatch', 'precision_ns': 1000},
    });
  }

  final String runId;
  final ValueChanged<String> sink;
  final Stopwatch _clock = Stopwatch();
  int _sequence = 0;

  void event(String name, [Map<String, Object?> data = const {}]) =>
      _write('event', {'name': name, 'data': data});

  void frame(IosSheetFrame frame) => _write('frame', {
    'metrics': frame.metrics,
    'state': frame.state,
    if (frame.unavailable.isNotEmpty) 'unavailable': frame.unavailable,
  });

  void _write(String type, Map<String, Object?> payload) {
    sink(
      '${jsonEncode({'schema_version': 1, 'type': type, 'run_id': runId, 'seq': _sequence++, 't_ns': _clock.elapsedMicroseconds * 1000, ...payload})}\n',
    );
  }
}
