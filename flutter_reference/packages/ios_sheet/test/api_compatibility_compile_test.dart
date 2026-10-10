import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

// These fixtures check Dart signatures. They do not present a route or assert
// native behavior, rendered geometry, or motion parity.
void main() {
  test('every existing route named parameter compiles through the wrapper', () {
    final controller = IosSheetController();
    final route = StupidSimpleIosSheetRoute<String>(
      child: const SizedBox.shrink(),
      profile: IosSheetProfile.ios26,
      detents: const [IosSheetDetent.medium, IosSheetDetent.large],
      initialDetentIdentifier: 'medium',
      largestUndimmedDetentIdentifier: 'medium',
      controller: controller,
      contentInteraction: IosSheetContentInteraction.scrolls,
      keyboardPolicy: IosSheetKeyboardPolicy.overlay,
      draggable: true,
      dismissible: true,
      interactiveDismissDisabled: false,
      backgroundColor: CupertinoColors.systemBackground,
      modalBarrierColor: const Color(0x33000000),
      onSelectedDetentChanged: (String identifier) {},
      onPresented: () {},
      onDismissed: () {},
      trajectoryModel: const FallbackIosSheetTrajectoryModel(
        CupertinoMotion.smooth(snapToEnd: true),
      ),
      onUnderlyingHitObserved:
          (IosSheetUnderlyingHitObservation observation) {},
      settings: const RouteSettings(
        name: 'compile-fixture',
        arguments: 'value',
      ),
    );
    expect(route, isA<StupidSimpleIosSheetRoute<String>>());
    // Keep typed action fixtures compiled without invoking detached actions.
    final void Function(IosSheetController) controllerActions =
        _controllerActions;
    final void Function(StupidSimpleIosSheetRoute<String>) engineActions =
        _engineActions;
    final List<Object?> Function(IosSheetState) stateAccess = _stateAccess;
    expect([
      controllerActions,
      engineActions,
      stateAccess,
    ], everyElement(isA<Function>()));
    controller.dispose();
  });

  test('selective engine re-exports retain their public types', () {
    const CupertinoMotion cupertino = CupertinoMotion.smooth(snapToEnd: true);
    const SpringMotion spring = cupertino;
    const CurvedMotion curved = CurvedMotion(Duration(milliseconds: 300));
    const List<Motion> motions = [spring, cupertino, curved];
    const FlingSnapPhysics fling = FlingSnapPhysics(minFlingVelocity: 50);
    const FrictionSnapPhysics friction = FrictionSnapPhysics(
      dragCoefficient: .135,
      constantDeceleration: 0,
    );
    const AbsoluteSnapPhysics absolute = fling;
    const RelativeSnapPhysics relative = friction;
    const List<SnapPhysics> physics = [absolute, relative, fling, friction];
    const SheetDragHandoff handoff = SheetDragHandoff.continuous;
    const RouteSnapshotMode snapshot = RouteSnapshotMode.never;
    expect([motions, physics, handoff, snapshot], hasLength(4));
  });

  test('legacy iOS 27 access remains source compatible', () {
    // ignore: deprecated_member_use_from_same_package
    final IosSheetProfile legacyProfile = IosSheetProfile.ios27;
    // ignore: deprecated_member_use_from_same_package
    final IosSheetProfile selectedProfile = IosSheetProfile.forMajorVersion(27);
    // ignore: deprecated_member_use_from_same_package
    final IosSheetProfile Function(int) legacyObserved =
        observedPage402x874Profile;
    final route = StupidSimpleIosSheetRoute<void>(
      child: const SizedBox.shrink(),
      profile: legacyProfile,
    );
    expect([
      route.profile,
      selectedProfile,
      legacyObserved(27),
    ], everyElement(isA<IosSheetProfile>()));
  });

  test('strict iOS 26 reference APIs retain their public signatures', () {
    const int version = iosSheetReferenceMajorVersion;
    const Set<int> supported = supportedIosSheetReferenceMajorVersions;
    final IosSheetProfile Function(int) resolveReference =
        IosSheetProfile.forReferenceVersion;
    final IosSheetProfile Function() observedReference =
        observedIos26Page402x874Profile;
    expect(supported, {version});
    expect(resolveReference(version), same(IosSheetProfile.ios26));
    expect(observedReference().majorVersion, version);
  });
}

void _controllerActions(IosSheetController controller) {
  final List<Object?> access = [
    controller.isAttached,
    controller.selectedDetentIdentifier,
    controller.requestedDetentIdentifier,
    controller.targetDetentIdentifier,
    controller.restingDetentIdentifier,
    controller.isPresented,
    controller.unscaledTrajectoryHeight,
    controller.unscaledSurfaceHeight,
    controller.renderedSurfaceHeight,
    controller.renderedVisibleHeight,
    controller.visibleHeight,
    controller.isModal,
  ];
  final IosSheetFrame frame = controller.captureFrame();
  final IosSheetState state = controller.snapshotState();
  controller.beginUnderlyingControlProbe(
    probeIdentifier: 'probe',
    controlIdentifier: 'control',
    position: Offset.zero,
  );
  controller.recordUnderlyingControlActivation('control');
  final IosSheetUnderlyingHitObservation? observation = controller
      .completeUnderlyingControlProbe();
  controller.selectDetent('large');
  controller.dismiss();
  controller.dismiss('result');
  // Consume typed values without making a runtime assertion about an open sheet.
  access.addAll([frame, state, observation]);
}

void _engineActions(StupidSimpleIosSheetRoute<String> route) {
  final TickerFuture animation = route.animateToRelative(.5, snap: true);
  final TickerFuture override = route.overrideSnappingConfig(
    route.snappingConfig,
    animateToComply: true,
  );
  final TickerFuture reset = route.overrideSnappingConfig(null);
  final List<TickerFuture> futures = [animation, override, reset];
  futures.clear();
}

List<Object?> _stateAccess(IosSheetState state) => [
  state.frame,
  state.position,
  state.velocity,
  state.phase,
  state.selectedDetent,
  state.targetDetent,
  state.restingDetent,
  state.gesture,
  state.sheetDragging,
  state.scroll,
  state.environment,
  state.capabilities,
  state.provenance,
  state.motionRequest,
  state.motionTargetPoints,
  state.presentation,
];
