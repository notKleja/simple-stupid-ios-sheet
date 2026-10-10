import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/src/stack.dart';

void main() {
  IosSheetLayerObservation observation({
    Rect? geometry,
    IosSheetObservationAvailability geometryAvailability =
        IosSheetObservationAvailability.unavailable,
    IosSheetObservationAvailability contourAvailability =
        IosSheetObservationAvailability.unavailable,
    bool? barrierEligible,
    bool? hitTestEligible,
    bool? semanticsEligible,
    String? liveProvenance,
    String? snapshotProvenance,
  }) => IosSheetLayerObservation(
    geometry: geometry,
    geometryAvailability: geometryAvailability,
    contourAvailability: contourAvailability,
    barrierEligible: barrierEligible,
    barrierAvailability: barrierEligible == null
        ? IosSheetObservationAvailability.unavailable
        : IosSheetObservationAvailability.observed,
    hitTestEligible: hitTestEligible,
    hitTestAvailability: hitTestEligible == null
        ? IosSheetObservationAvailability.unavailable
        : IosSheetObservationAvailability.observed,
    semanticsEligible: semanticsEligible,
    semanticsAvailability: semanticsEligible == null
        ? IosSheetObservationAvailability.unavailable
        : IosSheetObservationAvailability.observed,
    liveProvenance: liveProvenance,
    snapshotProvenance: snapshotProvenance,
  );

  test('fixture stack keeps unique IDs and rear state through unwind', () {
    final stack = IosSheetLayerStackObserver();
    final rear = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    final middle = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    final front = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );

    stack.didPush(rear, null);
    final rearLayerId = stack.layerIdForRoute(rear)!;
    expect(
      stack.observeLayer(
        rear,
        rearLayerId,
        observation(
          geometry: const Rect.fromLTWH(0, 420, 400, 380),
          geometryAvailability: IosSheetObservationAvailability.observed,
          contourAvailability: IosSheetObservationAvailability.unavailable,
          barrierEligible: true,
          hitTestEligible: true,
          semanticsEligible: true,
          liveProvenance: 'rear live fixture',
          snapshotProvenance: 'rear snapshot fixture',
        ),
      ),
      isTrue,
    );
    final rearId = stack.snapshot.layers.single.layerId;

    stack.didPush(middle, rear);
    final middleLayerId = stack.layerIdForRoute(middle)!;
    stack.observeLayer(
      middle,
      middleLayerId,
      observation(
        geometry: const Rect.fromLTWH(0, 500, 400, 300),
        geometryAvailability: IosSheetObservationAvailability.observed,
        contourAvailability: IosSheetObservationAvailability.observed,
        barrierEligible: true,
        hitTestEligible: true,
        semanticsEligible: true,
        liveProvenance: 'middle live fixture',
        snapshotProvenance: 'middle snapshot fixture',
      ),
    );
    final middleId = stack.snapshot.layers.last.layerId;

    stack.didPush(front, middle);
    final frontLayerId = stack.layerIdForRoute(front)!;
    stack.observeLayer(
      front,
      frontLayerId,
      observation(
        geometry: const Rect.fromLTWH(0, 560, 400, 240),
        geometryAvailability: IosSheetObservationAvailability.observed,
        contourAvailability: IosSheetObservationAvailability.notApplicable,
        barrierEligible: false,
        hitTestEligible: false,
        semanticsEligible: false,
        liveProvenance: 'front live fixture',
        snapshotProvenance: 'front snapshot fixture',
      ),
    );
    final frontId = stack.snapshot.layers.last.layerId;

    expect(stack.snapshot.layers.map((layer) => layer.layerId), [
      rearId,
      middleId,
      frontId,
    ]);
    expect(stack.snapshot.layers.map((layer) => layer.isFront), [
      false,
      false,
      true,
    ]);
    expect(
      stack.snapshot.layers.first.geometry,
      const Rect.fromLTWH(0, 420, 400, 380),
    );
    expect(stack.snapshot.layers.first.liveProvenance, 'rear live fixture');

    stack.didPop(front, middle);
    stack.didPop(middle, rear);

    final unwound = stack.snapshot.layers.single;
    expect(unwound.layerId, rearId);
    expect(unwound.isFront, isTrue);
    expect(unwound.geometry, const Rect.fromLTWH(0, 420, 400, 380));
    expect(
      unwound.contourAvailability,
      IosSheetObservationAvailability.unavailable,
    );
    expect(
      unwound.focusAvailability,
      IosSheetObservationAvailability.unavailable,
    );
    expect(unwound.focusOutcome, isNull);
  });

  test('popped top cannot overwrite surviving rear focus snapshot', () {
    final stack = IosSheetLayerStackObserver();
    final rear = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    final front = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    stack.didPush(rear, null);
    final rearLayerId = stack.layerIdForRoute(rear)!;
    stack.observeLayer(
      rear,
      rearLayerId,
      observation(liveProvenance: 'rear live'),
    );
    stack.didPush(front, rear);
    final frontLayerId = stack.layerIdForRoute(front)!;
    stack.observeLayer(
      front,
      frontLayerId,
      observation(liveProvenance: 'front live'),
    );

    expect(
      stack.recordTopFocusOutcome(
        front,
        frontLayerId,
        outcome: IosSheetFocusOutcome.focused,
        focused: true,
        provenance: 'front focus outcome',
      ),
      isTrue,
    );
    stack.didPop(front, rear);
    final rearBeforeStaleEvent = stack.snapshot.layers.single;

    expect(
      stack.recordTopFocusOutcome(
        front,
        frontLayerId,
        outcome: IosSheetFocusOutcome.dismissed,
        focused: false,
        provenance: 'stale top event',
      ),
      isFalse,
    );
    final rearAfterStaleEvent = stack.snapshot.layers.single;
    expect(rearAfterStaleEvent.layerId, rearBeforeStaleEvent.layerId);
    expect(rearAfterStaleEvent.focusOutcome, isNull);
    expect(rearAfterStaleEvent.liveProvenance, 'rear live');
  });

  test('absent layer observations stay explicitly unavailable', () {
    final stack = IosSheetLayerStackObserver();
    final route = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    stack.didPush(route, null);
    expect(
      stack.observeLayer(route, stack.layerIdForRoute(route)!, observation()),
      isTrue,
    );

    final layer = stack.snapshot.layers.single;
    expect(layer.geometry, isNull);
    expect(
      layer.geometryAvailability,
      IosSheetObservationAvailability.unavailable,
    );
    expect(
      layer.contourAvailability,
      IosSheetObservationAvailability.unavailable,
    );
    expect(layer.barrierEligible, isNull);
    expect(
      layer.barrierAvailability,
      IosSheetObservationAvailability.unavailable,
    );
    expect(layer.hitTestEligible, isNull);
    expect(
      layer.hitTestAvailability,
      IosSheetObservationAvailability.unavailable,
    );
    expect(layer.semanticsEligible, isNull);
    expect(
      layer.semanticsAvailability,
      IosSheetObservationAvailability.unavailable,
    );
    expect(layer.focused, isNull);
    expect(
      layer.focusAvailability,
      IosSheetObservationAvailability.unavailable,
    );
    expect(layer.liveProvenance, isNull);
    expect(layer.snapshotProvenance, isNull);
  });

  test('cancel removes only its active layer and IDs are never reused', () {
    final stack = IosSheetLayerStackObserver();
    final rear = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    final cancelled = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    final replacement = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    stack.didPush(rear, null);
    stack.observeLayer(
      rear,
      stack.layerIdForRoute(rear)!,
      observation(liveProvenance: 'rear live'),
    );
    final rearId = stack.snapshot.layers.single.layerId;
    stack.didPush(cancelled, rear);
    final cancelledId = stack.snapshot.layers.last.layerId;

    stack.didRemove(cancelled, rear);
    expect(stack.snapshot.layers.single.layerId, rearId);
    expect(stack.observeLayer(cancelled, cancelledId, observation()), isFalse);

    stack.didPush(replacement, rear);
    expect(stack.snapshot.layers.map((layer) => layer.layerId), [
      rearId,
      isNot(cancelledId),
    ]);
  });

  test('rejects incoherent observations and stale layer lifetimes', () {
    final stack = IosSheetLayerStackObserver();
    final route = PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox(),
    );
    stack.didPush(route, null);
    final retiredLayerId = stack.layerIdForRoute(route)!;

    expect(
      stack.observeLayer(
        route,
        retiredLayerId,
        observation(
          contourAvailability: IosSheetObservationAvailability.observed,
        ),
      ),
      isFalse,
    );
    expect(
      stack.observeLayer(
        route,
        retiredLayerId,
        observation(
          geometryAvailability: IosSheetObservationAvailability.observed,
          liveProvenance: 'live',
          snapshotProvenance: 'snapshot',
        ),
      ),
      isFalse,
    );
    expect(
      stack.observeLayer(
        route,
        retiredLayerId,
        observation(
          geometry: const Rect.fromLTWH(0, 1, 2, 3),
          geometryAvailability: IosSheetObservationAvailability.unavailable,
          liveProvenance: 'live',
          snapshotProvenance: 'snapshot',
        ),
      ),
      isFalse,
    );
    expect(
      stack.recordTopFocusOutcome(
        route,
        retiredLayerId,
        outcome: IosSheetFocusOutcome.focused,
        focused: false,
        provenance: 'contradiction',
      ),
      isFalse,
    );
    expect(
      stack.recordTopFocusOutcome(
        route,
        retiredLayerId,
        outcome: IosSheetFocusOutcome.dismissed,
        focused: true,
        provenance: 'contradiction',
      ),
      isFalse,
    );
    expect(
      stack.recordTopFocusOutcome(
        route,
        retiredLayerId,
        outcome: IosSheetFocusOutcome.focused,
        focused: true,
        provenance: ' ',
      ),
      isFalse,
    );

    stack.didRemove(route, null);
    stack.didPush(route, null);
    final currentLayerId = stack.layerIdForRoute(route)!;
    expect(currentLayerId, isNot(retiredLayerId));
    expect(
      stack.observeLayer(
        route,
        retiredLayerId,
        observation(liveProvenance: 'stale callback'),
      ),
      isFalse,
    );
    expect(
      stack.recordTopFocusOutcome(
        route,
        retiredLayerId,
        outcome: IosSheetFocusOutcome.focused,
        focused: true,
        provenance: 'stale callback',
      ),
      isFalse,
    );
    expect(stack.snapshot.layers.single.layerId, currentLayerId);
    expect(stack.snapshot.layers.single.geometry, isNull);
    expect(stack.snapshot.layers.single.focusOutcome, isNull);
  });

  testWidgets(
    'Navigator lifetime preserves layer identity and actual focus outcome',
    (tester) async {
      final stack = IosSheetLayerStackObserver();
      final navigator = GlobalKey<NavigatorState>();
      final rearFocus = FocusNode();
      final frontFocus = FocusNode();
      addTearDown(rearFocus.dispose);
      addTearDown(frontFocus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [stack],
          home: Scaffold(body: TextField(focusNode: rearFocus)),
        ),
      );
      final rear = MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: TextField(focusNode: rearFocus)),
        settings: const RouteSettings(name: 'rear'),
      );
      final front = MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: TextField(focusNode: frontFocus)),
        settings: const RouteSettings(name: 'front'),
      );
      navigator.currentState!.push(rear);
      await tester.pumpAndSettle();
      final rearLayerId = stack.layerIdForRoute(rear)!;
      stack.observeLayer(
        rear,
        rearLayerId,
        observation(
          geometry: tester.getRect(find.byType(TextField)),
          geometryAvailability: IosSheetObservationAvailability.observed,
          liveProvenance: 'actual Flutter widget bounds',
          snapshotProvenance: 'actual Navigator route lifetime',
        ),
      );
      final rearId = stack.snapshot.layers.last.layerId;

      navigator.currentState!.push(front);
      await tester.pumpAndSettle();
      final frontLayerId = stack.layerIdForRoute(front)!;
      frontFocus.requestFocus();
      await tester.pump();
      expect(frontFocus.hasFocus, isTrue);
      expect(
        stack.recordTopFocusOutcome(
          front,
          frontLayerId,
          outcome: IosSheetFocusOutcome.focused,
          focused: frontFocus.hasFocus,
          provenance: 'actual Flutter FocusNode outcome',
        ),
        isTrue,
      );
      final frontId = stack.snapshot.layers.last.layerId;

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      final remaining = stack.snapshot.layers.last;
      expect(remaining.layerId, rearId);
      expect(remaining.layerId, isNot(frontId));
      expect(remaining.isFront, isTrue);
      expect(remaining.geometry, tester.getRect(find.byType(TextField)));
      expect(
        stack.recordTopFocusOutcome(
          front,
          frontLayerId,
          outcome: IosSheetFocusOutcome.dismissed,
          focused: false,
          provenance: 'late popped-route callback',
        ),
        isFalse,
      );
    },
  );
}
