import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('opens the public sheet and offers medium and large controls', (
    tester,
  ) async {
    await tester.pumpWidget(const Ios26SheetExampleApp());
    expect(find.textContaining('iOS 27'), findsNothing);
    await tester.tap(find.text('Show iOS 26 sheet'));
    await tester.pumpAndSettle();

    expect(find.text('iOS 26 sheet content'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Large'), findsOneWidget);
    expect(find.textContaining('iOS 27'), findsNothing);

    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(find.text('Selected detent: large'), findsOneWidget);
    await tester.tap(find.text('Medium'));
    await tester.pumpAndSettle();
    expect(find.text('Selected detent: medium'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('iOS 26 sheet content'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
