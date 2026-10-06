import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_sheet_candidate/main.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  testWidgets('playground presents an opaque semantic medium sheet', (
    tester,
  ) async {
    await tester.pumpWidget(const IosSheetCandidateApp());
    expect(find.text('iOS sheet reference'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Present sheet'), 250);
    await tester.tap(find.text('Present sheet'));
    await tester.pumpAndSettle();
    expect(find.byKey(iosSheetSurfaceKey), findsOneWidget);
    expect(find.text('Calibration center'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
