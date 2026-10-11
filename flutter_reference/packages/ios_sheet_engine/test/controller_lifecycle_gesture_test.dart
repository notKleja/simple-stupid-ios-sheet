import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_sheet_engine/ios_sheet_engine.dart';
import 'package:ios_sheet_engine/src/controller_lifecycle_bridge.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';

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
  VoidCallback? duringSimulation;

  @override
  Simulation createSheetSimulation({
    required SheetSimulationPhase phase,
    required double start,
    required double end,
    required double velocity,
    double? dragReleaseVelocity,
  }) {
    simulations.add((phase: phase, end: end, velocity: velocity));
    if (phase == SheetSimulationPhase.detentSnap) duringSimulation?.call();
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
  for (final configuration in [
    (config: const SheetSnappingConfig([.4, 1], initialSnap: 1), target: .4),
    (config: const SheetSnappingConfig([0]), target: 1.0),
  ]) {
    testWidgets(
        'secondary pointer cancel after primary lift settles at '
        '${configuration.target} without pop', (tester) async {
      final route = _RecordingRoute(snappingConfig: configuration.config);
      final navigator = await _show(tester, route);
      var stops = 0;
      var cancels = 0;
      navigator.currentState!.userGestureInProgressNotifier.addListener(() {
        if (!navigator.currentState!.userGestureInProgress) stops++;
      });
      registerSheetControllerLifecycle(
        route,
        SheetControllerLifecycleCallbacks(
          onDragCancel: () => cancels++,
        ),
      );
      final first = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('sheet'))),
        pointer: 401,
      );
      await first.moveBy(const Offset(0, 30));
      expect(route.isUserDragging, isTrue);
      // Admit the secondary before Navigator installs IgnorePointer.
      // Both real pointers remain tracked across the next frame.
      final second = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('sheet'))),
        pointer: 402,
      );
      final beforeSecondaryMove = _value(route);
      await second.moveBy(const Offset(0, 30));
      expect(_value(route), isNot(beforeSecondaryMove));
      await first.up();
      await tester.pump();
      expect(route.isUserDragging, isTrue);
      expect(navigator.currentState!.userGestureInProgress, isTrue);
      expect(stops, 0);
      _position(route, .02);
      await second.cancel();
      expect(route.isUserDragging, isFalse);
      expect(navigator.currentState!.userGestureInProgress, isFalse);
      expect(stops, 1);
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
      expect(_value(route), closeTo(configuration.target, 1e-6));
      expect(cancels, 1);
      expect(route.simulations.last.velocity, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(stops, 1);
      expect(cancels, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'bridge teardown emits cancel once before disposal without motion',
      (tester) async {
    final route = _RecordingRoute();
    await _show(tester, route);
    var cancels = 0;
    registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(
        onDragCancel: () {
          expect(route.isUserDragging, isFalse);
          cancels++;
        },
      ),
    );
    final gesture = await _acquire(tester, route);
    final count = route.simulations.length;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(cancels, 1);
    await gesture.cancel();
    dispatchSheetDragCancel(route);
    expect(cancels, 1);
    expect(route.simulations.length, count);
  });

  testWidgets('bridge scroll takeover ends ownership without starting motion',
      (tester) async {
    final route = _RecordingRoute();
    final navigator = await _show(tester, route);
    var ends = 0;
    registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(
        onDragEnd: () {
          expect(route.isUserDragging, isFalse);
          expect(navigator.currentState!.userGestureInProgress, isFalse);
          ends++;
        },
      ),
    );
    final gesture = await _acquire(tester, route);
    final count = route.simulations.length;
    tester
        .widget<ScrollDragDetector>(find.byType(ScrollDragDetector))
        .onVerticalDragEnd!(DragEndDetails(), true);
    expect(ends, 1);
    expect(route.simulations.length, count);
    await gesture.cancel();
    expect(ends, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'bridge overdrag end observes released ownership after return starts',
      (tester) async {
    final route = _RecordingRoute();
    await _show(tester, route);
    var ends = 0;
    registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(
        onDragEnd: () {
          expect(route.isUserDragging, isFalse);
          expect(
            route.simulations.last.phase,
            SheetSimulationPhase.overdragReturn,
          );
          ends++;
        },
      ),
    );
    final gesture = await _acquire(tester, route);
    _position(route, 1.2);
    await gesture.up();
    expect(ends, 1);
    await tester.pumpAndSettle();
    expect(_value(route), closeTo(1, 1e-6));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'bridge observes ownership before Navigator start and after cancel',
      (tester) async {
    final route = _RecordingRoute();
    final navigator = await _show(tester, route);
    final events = <String>[];
    registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(
        onDragStart: () {
          expect(route.isUserDragging, isTrue);
          expect(navigator.currentState!.userGestureInProgress, isFalse);
          events.add('start');
        },
        onDragCancel: () {
          expect(route.isUserDragging, isFalse);
          expect(navigator.currentState!.userGestureInProgress, isFalse);
          events.add('cancel');
        },
      ),
    );
    final gesture = await _acquire(tester, route);
    await gesture.cancel();
    expect(events, ['start', 'cancel']);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    dispatchSheetDragStart(route);
    dispatchSheetDragCancel(route);
    expect(events, ['start', 'cancel']);
  });

  testWidgets(
      'bridge normal release and popped release observe cleared ownership',
      (tester) async {
    final route = _RecordingRoute();
    final navigator = await _show(tester, route);
    var ends = 0;
    registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(
        onDragEnd: () {
          expect(route.isUserDragging, isFalse);
          expect(navigator.currentState!.userGestureInProgress, isFalse);
          ends++;
        },
      ),
    );
    final first = await _acquire(tester, route);
    await first.up();
    await tester.pumpAndSettle();
    expect(ends, 1);
    final second = await _acquire(tester, route);
    navigator.currentState!.pop();
    await second.up();
    expect(ends, 2);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'validated bridge start follows construction before engine mutation',
      (tester) async {
    final route = _RecordingRoute();
    await _show(tester, route);
    final events = <String>[];
    route.duringSimulation = () => events.add('construct');
    registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(
        onProgrammaticDetentStart: () {
          events.add('start');
          expect(route.targetRelativePosition, 1);
          // ignore: invalid_use_of_protected_member
          expect(route.controller!.isAnimating, isFalse);
          return true;
        },
      ),
    );
    route.animateToRelative(.5).ignore();
    expect(events, ['construct', 'start']);
    expect(route.targetRelativePosition, .5);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('validated bridge shortcut starts no ticker and preserves target',
      (tester) async {
    final route = _RecordingRoute();
    await _show(tester, route);
    registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(onProgrammaticDetentStart: () => false),
    );
    var completed = false;
    route.animateToRelative(.5).orCancel.then((_) => completed = true).ignore();
    expect(route.targetRelativePosition, 1);
    // ignore: invalid_use_of_protected_member
    expect(route.controller!.isAnimating, isFalse);
    await tester.idle();
    expect(completed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('bridge rejection preserves prior ticker and engine target',
      (tester) async {
    final route = _RecordingRoute();
    await _show(tester, route);
    final prior = route.animateToRelative(.7);
    var completed = false;
    prior.orCancel
        .then<void>(
          (_) => completed = true,
          onError: (Object error) {},
        )
        .ignore();
    registerSheetControllerLifecycle(
      route,
      SheetControllerLifecycleCallbacks(
        onProgrammaticDetentStart: () {
          throw StateError('attempt no longer owns route');
        },
      ),
    );
    expect(
      () {
        route.animateToRelative(.4);
      },
      throwsStateError,
    );
    expect(route.targetRelativePosition, .7);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
