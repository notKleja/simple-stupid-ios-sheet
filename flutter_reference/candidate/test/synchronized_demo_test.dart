import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_sheet_candidate/synchronized_demo.dart';

const fixture = '''
{
  "schema_version": 1,
  "duration_ms": 9000,
  "scenes": [
    {
      "id": "en.page", "language": "en", "direction": "ltr",
      "kind": "page", "start_ms": 0, "duration_ms": 4000,
      "title": "Page sheet", "subtitle": "Medium and large",
      "configuration": {"detents": "reference"},
      "actions": [
        {"at_ms": 500, "type": "present", "detent": "medium"},
        {"at_ms": 2500, "type": "select", "detent": "large"}
      ]
    },
    {
      "id": "ar.page", "language": "ar", "direction": "rtl",
      "kind": "page", "start_ms": 4000, "duration_ms": 5000,
      "title": "ورقة الصفحة", "subtitle": "متوسطة وكبيرة",
      "configuration": {"detents": "reference"},
      "actions": [
        {"at_ms": 500, "type": "present", "detent": "medium"},
        {"at_ms": 2500, "type": "select", "detent": "large"}
      ]
    }
  ]
}
''';

void main() {
  test('absolute elapsed time selects scenes and actions', () {
    final timeline = DemoTimeline.fromJson(jsonDecode(fixture) as Map<String, Object?>);
    expect(timeline.sceneAt(3999).id, 'en.page');
    expect(timeline.sceneAt(4000).id, 'ar.page');
    expect(
      timeline.actionsBetween(4300, 6600).map((action) => action.type),
      ['present', 'select'],
    );
    expect(timeline.actionsBetween(6600, 6700), isEmpty);
  });

  testWidgets('Arabic scene renders localized copy with RTL direction', (tester) async {
    final timeline = DemoTimeline.fromJson(jsonDecode(fixture) as Map<String, Object?>);
    await tester.pumpWidget(
      MaterialApp(home: DemoStage(timeline: timeline, elapsedMs: 4500, implementation: 'Flutter')),
    );
    expect(find.text('ورقة الصفحة'), findsOneWidget);
    final directionality = tester.widget<Directionality>(
      find.ancestor(of: find.text('ورقة الصفحة'), matching: find.byType(Directionality)).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('English scene renders LTR implementation and time overlay', (tester) async {
    final timeline = DemoTimeline.fromJson(jsonDecode(fixture) as Map<String, Object?>);
    await tester.pumpWidget(
      MaterialApp(home: DemoStage(timeline: timeline, elapsedMs: 1250, implementation: 'Flutter')),
    );
    expect(find.text('Page sheet'), findsOneWidget);
    expect(find.textContaining('Flutter'), findsOneWidget);
    expect(find.textContaining('01.250'), findsOneWidget);
    final directionality = tester.widget<Directionality>(
      find.ancestor(of: find.text('Page sheet'), matching: find.byType(Directionality)).first,
    );
    expect(directionality.textDirection, TextDirection.ltr);
  });

  testWidgets('visible sync marker appears only during the first timeline second', (tester) async {
    final timeline = DemoTimeline.fromJson(jsonDecode(fixture) as Map<String, Object?>);
    Future<void> pump(int elapsed) => tester.pumpWidget(MaterialApp(home: DemoStage(timeline: timeline, elapsedMs: elapsed, implementation: 'Flutter')));
    await pump(-1);
    expect(find.byKey(const ValueKey('demo-sync-marker')), findsNothing);
    await pump(0);
    expect(find.byKey(const ValueKey('demo-sync-marker')), findsOneWidget);
    await pump(999);
    expect(find.byKey(const ValueKey('demo-sync-marker')), findsOneWidget);
    await pump(1000);
    expect(find.byKey(const ValueKey('demo-sync-marker')), findsNothing);
    await pump(timeline.durationMs - 1000);
    expect(find.byKey(const ValueKey('demo-sync-marker')), findsOneWidget);
    await pump(timeline.durationMs);
    expect(find.byKey(const ValueKey('demo-sync-marker')), findsNothing);
  });

  testWidgets('component gallery supplies its own Material ancestor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: DemoComponentGallery(
            language: 'en',
            toggleValue: false,
            onToggle: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Component gallery'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
