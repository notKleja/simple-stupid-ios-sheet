import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_sheet_candidate/main.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  testWidgets('shows iOS 26 as the only reference target', (tester) async {
    await tester.pumpWidget(const IosSheetCandidateApp());
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.textContaining('iOS 26'), findsWidgets);
    expect(find.textContaining('iOS 27'), findsNothing);
  });

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
    final route =
        ModalRoute.of(tester.element(find.text('Calibration center')))!
            as StupidSimpleIosSheetRoute<void>;
    expect(route.profile.majorVersion, 26);
  });
}
