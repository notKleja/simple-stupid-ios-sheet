import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  test(
    'JSONL recorder preserves scenario metadata and command boundary order',
    () {
      final lines = <String>[];
      final recorder = IosSheetTraceRecorder(
        runId: 'trial-1',
        scenarioId: 'native.medium_large.programmatic',
        sink: lines.add,
        os: const {'version': '26.4.1', 'build': 'fixture'},
        device: const {'runtime_kind': 'synthetic-test'},
        environment: const {},
        configuration: const {},
        evidenceKind: 'synthetic',
      );
      recorder.event('present.requested');
      recorder.frame(
        const IosSheetFrame(
          metrics: {'sheet.y': 400, 'barrier.alpha': null},
          state: {'selected_detent': 'medium'},
          unavailable: {'barrier.alpha': 'unobserved in fixture'},
        ),
      );
      final records = lines.map((line) => jsonDecode(line) as Map).toList();
      expect(records.map((r) => r['type']), ['session', 'event', 'frame']);
      expect(records.map((r) => r['seq']), [0, 1, 2]);
      expect(records.first['scenario_id'], 'native.medium_large.programmatic');
      expect(records.first['implementation'], 'flutter');
      expect(records[1]['name'], 'present.requested');
      expect(records[2]['metrics']['sheet.y'], 400);
      expect(records[2]['metrics']['barrier.alpha'], isNull);
      expect(
        records[2]['unavailable']['barrier.alpha'],
        'unobserved in fixture',
      );
      expect(records.map((r) => r['t_ns']).every((t) => t is int), isTrue);
      expect(
        records[2]['t_ns'] as int,
        greaterThanOrEqualTo(records[1]['t_ns'] as int),
      );
    },
  );
}
