import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_sheet_engine/ios_sheet_engine.dart';

void main() {
  testWidgets(
      'generic programmatic dismissal retains legacy zero release velocity',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox.expand()),
    );
    final route = StupidSimpleSheetRoute<void>(
      snappingConfig: const SheetSnappingConfig([.3, 1], initialSnap: .3),
      child: const Center(child: Text('Generic control')),
    );
    navigator.currentState!.push(route).ignore();
    await tester.pumpAndSettle();
    // ignore: invalid_use_of_protected_member
    final engine = route.controller!;
    route.animateToRelative(1).ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final position = engine.value;
    expect(engine.velocity, greaterThan(0));
    navigator.currentState!.pop();
    expect(engine.value, closeTo(position, 1e-10));
    expect(engine.velocity, 0);
    await tester.pumpAndSettle();
  });
}
