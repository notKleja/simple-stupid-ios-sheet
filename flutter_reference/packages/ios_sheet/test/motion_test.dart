import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  late IosSheetController sheet;
  late StupidSimpleIosSheetRoute<void> route;
  Future<void> present(
    WidgetTester tester, {
    bool fixedOpening = false,
    IosSheetTrajectoryModel? model,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigator = GlobalKey<NavigatorState>();
    sheet = IosSheetController();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox.expand()),
    );
    route = StupidSimpleIosSheetRoute<void>(
      controller: sheet,
      trajectoryModel: model,
      profile: IosSheetProfile.ios26.copyWith(
        fixedSurfaceDuringTransition: fixedOpening,
      ),
      detents: [IosSheetDetent.height('short', 300), IosSheetDetent.large],
      initialDetentIdentifier: 'short',
      child: const Center(child: Text('Motion control')),
    );
    navigator.currentState!.push(route);
    if (fixedOpening) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'detent reversal captures current point position and velocity without a jump',
    (tester) async {
      await present(tester);
      // ignore: invalid_use_of_protected_member
      final engine = route.controller!;
      sheet.selectDetent('large');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final position = engine.value, velocity = engine.velocity;
      expect(velocity, greaterThan(0));
      sheet.selectDetent('short');
      final state = sheet.snapshotState();
      final request = state.motionRequest!;
      expect(request.kind, IosSheetMotionKind.detentSnap);
      expect(request.positionPoints, closeTo(position * 800, 1e-8));
      expect(request.velocityPointsPerSecond, closeTo(velocity * 800, 1e-8));
      expect(request.targetPoints, 300);
      expect(request.velocitySource, IosSheetVelocitySource.controller);
      expect(engine.value, closeTo(position, 1e-10));
      expect(engine.velocity, closeTo(velocity, 1e-10));
      expect(state.motionTargetPoints, 300);
      expect(state.capabilities['motion'], IosSheetCapabilityStatus.fallback);
      expect(state.provenance['motion'], isNotEmpty);
      final repeated = sheet.snapshotState();
      expect(repeated.motionRequest, same(request));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dismissal request preserves live controller velocity and zero target',
    (tester) async {
      await present(tester);
      // ignore: invalid_use_of_protected_member
      final engine = route.controller!;
      sheet.selectDetent('large');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final velocity = engine.velocity;
      sheet.dismiss();
      final request = sheet.snapshotState().motionRequest!;
      expect(request.kind, IosSheetMotionKind.dismissal);
      expect(request.velocityPointsPerSecond, closeTo(velocity * 800, 1e-8));
      expect(request.targetPoints, 0);
      expect(request.dragReleaseVelocityPointsPerSecond, isNull);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'actual drag release takes precedence over stopped controller velocity',
    (tester) async {
      await present(tester);
      await tester.timedDrag(
        find.text('Motion control'),
        const Offset(0, -80),
        const Duration(milliseconds: 100),
      );
      final request = sheet.snapshotState().motionRequest!;
      expect(request.velocitySource, IosSheetVelocitySource.dragRelease);
      expect(request.dragReleaseVelocityPointsPerSecond, greaterThan(0));
      expect(
        request.velocityPointsPerSecond,
        request.dragReleaseVelocityPointsPerSecond,
      );
      expect(request.kind, IosSheetMotionKind.detentSnap);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'fixed opening still rejects retarget without creating a request',
    (tester) async {
      await present(tester, fixedOpening: true);
      await tester.pump(const Duration(milliseconds: 100));
      final original = sheet.snapshotState().motionRequest;
      expect(original!.kind, IosSheetMotionKind.presentation);
      expect(() => sheet.selectDetent('large'), throwsStateError);
      expect(() => sheet.dismiss(), throwsStateError);
      expect(sheet.snapshotState().motionRequest, same(original));
      expect(sheet.selectedDetentIdentifier, 'short');
      await tester.pumpAndSettle();
    },
  );

  test(
    'rebase and invalidation request interfaces contain only supplied point data',
    () {
      for (final kind in [
        IosSheetMotionKind.environmentRebase,
        IosSheetMotionKind.keyboardRebase,
        IosSheetMotionKind.contentInvalidation,
      ]) {
        final request = IosSheetMotionRequest(
          kind: kind,
          positionPoints: 350,
          velocityPointsPerSecond: -120,
          targetPoints: 300,
          referenceHeightPoints: 800,
          velocitySource: IosSheetVelocitySource.controller,
          environment: const IosSheetEnvironment(
            availableSize: Size(400, 800),
            maximumDetentHeight: 800,
          ),
        );
        final trajectory = FallbackIosSheetTrajectoryModel(
          const CupertinoMotion.smooth(snapToEnd: true),
        ).createTrajectory(request);
        expect(trajectory.simulation.x(0), 350);
        expect(trajectory.simulation.dx(0), closeTo(-120, 1e-8));
        expect(trajectory.targetPoints, 300);
        expect(trajectory.capability, IosSheetCapabilityStatus.fallback);
      }
    },
  );
  testWidgets(
    'injected model provenance is observed and inconsistent target is rejected',
    (tester) async {
      final model = _ControlledModel();
      await present(tester, model: model);
      final original = sheet.snapshotState().motionRequest;
      expect(
        sheet.snapshotState().provenance['motion'],
        'synthetic injected model, not native evidence',
      );
      model.wrongTarget = true;
      expect(() => sheet.selectDetent('large'), throwsStateError);
      expect(sheet.selectedDetentIdentifier, 'short');
      expect(sheet.snapshotState().motionRequest, same(original));
      expect(sheet.unscaledTrajectoryHeight, 300);
    },
  );
  testWidgets('injected model cannot jump the initial point position', (
    tester,
  ) async {
    final model = _ControlledModel();
    await present(tester, model: model);
    final original = sheet.snapshotState().motionRequest;
    model.wrongPosition = true;
    expect(() => sheet.selectDetent('large'), throwsStateError);
    expect(sheet.selectedDetentIdentifier, 'short');
    expect(sheet.snapshotState().motionRequest, same(original));
    expect(sheet.unscaledTrajectoryHeight, 300);
  });
  testWidgets('injected model must preserve finite initial point velocity', (
    tester,
  ) async {
    final model = _ControlledModel();
    await present(tester, model: model);
    sheet.selectDetent('large');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // ignore: invalid_use_of_protected_member
    expect(route.controller!.velocity, greaterThan(0));
    final original = sheet.snapshotState().motionRequest;
    for (final velocity in [0.0, double.nan]) {
      model.initialVelocityOverride = velocity;
      expect(() => sheet.selectDetent('short'), throwsStateError);
      expect(sheet.selectedDetentIdentifier, 'large');
      expect(sheet.snapshotState().motionRequest, same(original));
    }
    await tester.pumpAndSettle();
  });
}

class _ControlledModel implements IosSheetTrajectoryModel {
  bool wrongTarget = false;
  bool wrongPosition = false;
  double? initialVelocityOverride;
  @override
  IosSheetTrajectory createTrajectory(IosSheetMotionRequest request) {
    final base = FallbackIosSheetTrajectoryModel(
      const CupertinoMotion.smooth(snapToEnd: true),
    ).createTrajectory(request);
    return IosSheetTrajectory(
      simulation: wrongPosition || initialVelocityOverride != null
          ? _ControlledSimulation(
              base.simulation,
              positionShift: wrongPosition ? 1 : 0,
              initialVelocityOverride: initialVelocityOverride,
            )
          : base.simulation,
      targetPoints: request.targetPoints + (wrongTarget ? 1 : 0),
      provenance: 'synthetic injected model, not native evidence',
      capability: IosSheetCapabilityStatus.fallback,
    );
  }
}

class _ControlledSimulation extends Simulation {
  _ControlledSimulation(
    this.inner, {
    required this.positionShift,
    required this.initialVelocityOverride,
  });
  final Simulation inner;
  final double positionShift;
  final double? initialVelocityOverride;
  @override
  double x(double time) => inner.x(time) + positionShift;
  @override
  double dx(double time) => time == 0 && initialVelocityOverride != null
      ? initialVelocityOverride!
      : inner.dx(time);
  @override
  bool isDone(double time) => inner.isDone(time);
}
