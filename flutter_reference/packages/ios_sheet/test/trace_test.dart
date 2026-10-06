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
        configuration: iosPageReferenceConfiguration(trial: 1),
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

  test('page reference configuration uses only native comparison keys', () {
    expect(iosPageReferenceConfiguration(trial: 3), {
      'trial': 3,
      'detents': ['fixed320', 'medium', 'large'],
      'surface': 'opaque.white',
      'grabber': true,
      'page_sizing': true,
      'modal_in_presentation': false,
      'largest_undimmed': null,
      'presentation_style': 'page_sheet',
      'preferred_content_size': {'width': 320, 'height': 320},
      'placement': 'automatic',
      'edge_attached_in_compact_height': false,
      'width_follows_preferred_content_size': false,
      'scroll_expansion': true,
    });
  });

  test(
    'implementation provenance cannot silently become comparison configuration',
    () {
      final config = iosPageReferenceConfiguration(trial: 1);
      expect(
        () => canonicalIosSheetConfiguration({...config, 'profile_major': 27}),
        throwsArgumentError,
      );
      final lines = <String>[];
      final recorder = IosSheetTraceRecorder(
        runId: 'provenance',
        scenarioId: 'native.medium_large.programmatic',
        sink: lines.add,
        os: const {'version': '27.0', 'build': 'fixture'},
        device: const {},
        environment: const {},
        configuration: config,
        implementationProvenance: const {
          'profile_major': 27,
          'profile_evidence': 'fixture',
        },
        evidenceKind: 'synthetic',
      );
      recorder.eventWithProvenance(
        'present.completed',
        implementationProvenance: const {'detector': 'engine status'},
      );
      final session = jsonDecode(lines.first) as Map;
      expect(session['native_contract_version'], 2);
      expect(session['configuration'], config);
      expect(session['provenance']['implementation']['profile_major'], 27);
      final event = jsonDecode(lines.last) as Map;
      expect(event['data'], isEmpty);
      expect(event['provenance']['detector'], 'engine status');
      recorder.event('dismiss.completed');
      expect((jsonDecode(lines.last) as Map)['terminal'], isTrue);
    },
  );

  test('canonical detent IDs retain raw values outside comparison state', () {
    final lines = <String>[];
    final recorder = IosSheetTraceRecorder(
      runId: 'ids',
      scenarioId: 'native.medium_large.programmatic',
      sink: lines.add,
      os: const {'version': '27.0', 'build': 'fixture'},
      device: const {},
      environment: const {},
      configuration: iosPageReferenceConfiguration(trial: 1),
      evidenceKind: 'synthetic',
    );
    recorder.frame(
      const IosSheetFrame(
        metrics: {},
        state: {
          'selected_detent': 'com.apple.UIKit.medium',
          'target_detent': 'com.apple.UIKit.large',
        },
        implementationProvenance: {'resting_detent': 'medium'},
      ),
    );
    final frame = jsonDecode(lines.last) as Map;
    expect(frame['state']['selected_detent'], 'medium');
    expect(frame['state']['target_detent'], 'large');
    expect(
      frame['raw_detent_identifiers']['selected_detent'],
      'com.apple.UIKit.medium',
    );
    expect(frame['provenance']['resting_detent'], 'medium');
  });
}
