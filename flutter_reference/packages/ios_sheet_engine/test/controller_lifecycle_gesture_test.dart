import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_sheet_engine/ios_sheet_engine.dart';

class _RecordingRoute extends StupidSimpleSheetRoute<void> {
  _RecordingRoute({super.snappingConfig})
      : super(
          callNavigatorUserGestureMethods: true,
          child: const ColoredBox(
            color: Colors.white,
            child: SizedBox.expand(key: ValueKey('sheet')),
          ),
        );

  final simulations =
      <({SheetSimulationPhase phase, double end, double velocity})>[];
  bool? draggingAtDispose;

  @override
  Simulation createSheetSimulation({
    required SheetSimulationPhase phase,
    required double start,
    required double end,
    required double velocity,
    double? dragReleaseVelocity,
  }) {
    simulations.add((phase: phase, end: end, velocity: velocity));
    return super.createSheetSimulation(
      phase: phase,
      start: start,
      end: end,
      velocity: velocity,
      dragReleaseVelocity: dragReleaseVelocity,
    );
  }

  @override
  void dispose() {
    draggingAtDispose = isUserDragging;
    super.dispose();
  }
}

Future<GlobalKey<NavigatorState>> _show(
  WidgetTester tester,
  _RecordingRoute route,
) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(navigatorKey: navigator, home: const SizedBox.expand()),
  );
  navigator.currentState!.push(route).ignore();
  await tester.pumpAndSettle();
  return navigator;
}

Future<TestGesture> _acquire(WidgetTester tester, _RecordingRoute route) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(const ValueKey('sheet'))),
  );
  await gesture.moveBy(const Offset(0, 30));
  await tester.pump();
  expect(route.isUserDragging, isTrue);
  return gesture;
}

// The position setter isolates release/cancel target selection from pointer
// geometry; acquisition and cancellation still use the real recognizer.
void _position(_RecordingRoute route, double value) {
  // ignore: invalid_use_of_protected_member
  route.controller!.value = value;
}

double _value(_RecordingRoute route) {
  // ignore: invalid_use_of_protected_member
  return route.controller!.value;
}

void main() {
  testWidgets('cancel clears drag ownership and ends Navigator gesture once',
      (tester) async {
    final route = _RecordingRoute();
    final navigator = await _show(tester, route);
    var stops = 0;
    navigator.currentState!.userGestureInProgressNotifier.addListener(() {
      if (!navigator.currentState!.userGestureInProgress) stops++;
    });
    final gesture = await _acquire(tester, route);
    expect(navigator.currentState!.userGestureInProgress, isTrue);
    await gesture.cancel();
    expect(route.isUserDragging, isFalse);
    expect(navigator.currentState!.userGestureInProgress, isFalse);
    await tester.pumpAndSettle();
    expect(_value(route), closeTo(1, 1e-6));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(stops, 1);
  });

  testWidgets('near-closed cancel snaps to configured open detent without pop',
      (tester) async {
    final route = _RecordingRoute(
      snappingConfig: const SheetSnappingConfig([.4, 1], initialSnap: 1),
    );
    final navigator = await _show(tester, route);
    final gesture = await _acquire(tester, route);
    _position(route, .02);
    await gesture.cancel();
    expect(route.isUserDragging, isFalse);
    await tester.pumpAndSettle();
    expect(route.isCurrent, isTrue);
    expect(navigator.currentState!.canPop(), isTrue);
    expect(_value(route), closeTo(.4, 1e-6));
    expect(route.simulations.last.velocity, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancel without configured nonzero detent settles open',
      (tester) async {
    final route =
        _RecordingRoute(snappingConfig: const SheetSnappingConfig([0]));
    final navigator = await _show(tester, route);
    final gesture = await _acquire(tester, route);
    _position(route, .1);
    await gesture.cancel();
    expect(route.isUserDragging, isFalse);
    await tester.pumpAndSettle();
    expect(route.isCurrent, isTrue);
    expect(navigator.currentState!.canPop(), isTrue);
    expect(_value(route), closeTo(1, 1e-6));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancel after pop preserves dismissal motion', (tester) async {
    final route = _RecordingRoute();
    final navigator = await _show(tester, route);
    final gesture = await _acquire(tester, route);
    navigator.currentState!.pop();
    final simulationCount = route.simulations.length;
    await gesture.cancel();
    expect(route.isUserDragging, isFalse);
    expect(navigator.currentState!.userGestureInProgress, isFalse);
    expect(route.simulations.length, simulationCount);
    await tester.pumpAndSettle();
  });

  testWidgets('unmount during drag releases ownership without starting motion',
      (tester) async {
    final route = _RecordingRoute();
    await _show(tester, route);
    final gesture = await _acquire(tester, route);
    final simulationCount = route.simulations.length;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(route.draggingAtDispose, isFalse);
    expect(route.simulations.length, simulationCount);
    await gesture.cancel();
    expect(route.simulations.length, simulationCount);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal near-closed release still dismisses', (tester) async {
    final route = _RecordingRoute();
    final navigator = await _show(tester, route);
    final gesture = await _acquire(tester, route);
    _position(route, .02);
    await gesture.up();
    expect(route.isUserDragging, isFalse);
    expect(navigator.currentState!.userGestureInProgress, isFalse);
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), isFalse);
    expect(route.simulations.last.phase, SheetSimulationPhase.dismissal);
  });
}
