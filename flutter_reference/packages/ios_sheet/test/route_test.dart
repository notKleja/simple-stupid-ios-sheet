import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  late GlobalKey<NavigatorState> navigator;
  late IosSheetController controller;
  late int backgroundTaps;

  Future<void> present(
    WidgetTester tester, {
    String? undimmed,
    bool interactiveDismissDisabled = false,
    bool draggable = true,
    IosSheetContentInteraction interaction = IosSheetContentInteraction.resizes,
    IosSheetProfile? profile,
    Widget? child,
    ValueChanged<String>? onSelected,
    bool settle = true,
    MediaQueryData? media,
    List<IosSheetDetent>? detents,
    String initial = 'short',
    IosSheetKeyboardPolicy keyboardPolicy = IosSheetKeyboardPolicy.resize,
  }) async {
    await tester.binding.setSurfaceSize(media?.size ?? const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    navigator = GlobalKey<NavigatorState>();
    controller = IosSheetController();
    backgroundTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) =>
            media == null ? child! : MediaQuery(data: media, child: child!),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: TextButton(
              onPressed: () => backgroundTaps++,
              child: const Text('Background control'),
            ),
          ),
        ),
      ),
    );
    navigator.currentState!.push(
      StupidSimpleIosSheetRoute<void>(
        profile: profile ?? IosSheetProfile.ios26,
        detents:
            detents ??
            [IosSheetDetent.height('short', 300), IosSheetDetent.large],
        initialDetentIdentifier: initial,
        largestUndimmedDetentIdentifier: undimmed,
        controller: controller,
        keyboardPolicy: keyboardPolicy,
        interactiveDismissDisabled: interactiveDismissDisabled,
        draggable: draggable,
        contentInteraction: interaction,
        onSelectedDetentChanged: onSelected,
        child:
            child ??
            const ColoredBox(
              color: Colors.white,
              child: Center(child: Text('Sheet content')),
            ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('fixed detent resizes opaque surface to its resolved height', (
    tester,
  ) async {
    await present(tester);
    expect(tester.getSize(find.byKey(iosSheetSurfaceKey)).height, 300);
    expect(controller.selectedDetentIdentifier, 'short');
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('undimmed threshold passes real background taps', (tester) async {
    await present(tester, undimmed: 'short');
    await tester.tap(find.text('Background control'));
    expect(backgroundTaps, 1);
    expect(controller.isModal, isFalse);
  });

  testWidgets('crossing undimmed threshold blocks background taps', (
    tester,
  ) async {
    await present(tester, undimmed: 'short');
    controller.selectDetent('large');
    await tester.pumpAndSettle();
    // The large sheet covers the control; both sheet and barrier block it.
    await tester.tapAt(const Offset(200, 20));
    expect(backgroundTaps, 0);
    expect(controller.isModal, isTrue);
  });

  testWidgets('selected detent callback follows settled programmatic changes', (
    tester,
  ) async {
    final changes = <String>[];
    await present(tester, onSelected: changes.add);
    controller.selectDetent('large');
    await tester.pumpAndSettle();
    expect(controller.selectedDetentIdentifier, 'large');
    expect(changes, contains('large'));
    expect(() => controller.selectDetent('missing'), throwsArgumentError);
  });

  testWidgets('interactive dismissal lock still allows explicit dismissal', (
    tester,
  ) async {
    await present(tester, interactiveDismissDisabled: true);
    await tester.drag(find.text('Sheet content'), const Offset(0, 650));
    await tester.pumpAndSettle();
    expect(find.text('Sheet content'), findsOneWidget);
    controller.dismiss();
    await tester.pumpAndSettle();
    expect(find.text('Sheet content'), findsNothing);
    expect(controller.isAttached, isFalse);
  });

  testWidgets('scrolls policy consumes upward content drag at medium', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await present(
      tester,
      interaction: IosSheetContentInteraction.scrolls,
      child: ListView.builder(
        controller: scroll,
        itemExtent: 50,
        itemCount: 100,
        itemBuilder: (_, i) => Text('Row $i'),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(controller.visibleHeight, closeTo(300, .01));
  });

  testWidgets('profile geometry controls side and bottom spacing', (
    tester,
  ) async {
    await present(
      tester,
      profile: IosSheetProfile.ios27.copyWith(
        geometry: (_) => const IosSheetGeometry(
          sideInset: 12,
          bottomInset: 8,
          cornerRadius: 16,
        ),
        evidence: {'geometry': 'synthetic test fixture'},
      ),
    );
    final surface = find.byKey(iosSheetSurfaceKey);
    expect(tester.getSize(surface), const Size(376, 300));
    expect(tester.getTopLeft(surface), const Offset(12, 492));
  });

  testWidgets('detached controller rejects selection without touching route', (
    tester,
  ) async {
    final detached = IosSheetController();
    expect(() => detached.selectDetent('large'), throwsStateError);
  });

  testWidgets('repeated captureFrame is observational during engine retarget', (
    tester,
  ) async {
    final selections = <String>[];
    await present(tester, onSelected: selections.add);
    final route =
        ModalRoute.of(tester.element(find.text('Sheet content')))!
            as StupidSimpleIosSheetRoute<void>;
    // First enter the forward animation status at an unconfigured extent.
    // The next retarget has no status change to synchronize semantic IDs yet.
    route.animateToRelative(.7);
    route.animateToRelative(1);
    expect(controller.selectedDetentIdentifier, 'short');
    expect(controller.targetDetentIdentifier, 'large');
    var notifications = 0;
    controller.addListener(() => notifications++);
    final first = controller.captureFrame();
    final second = controller.captureFrame();
    expect(selections, isEmpty);
    expect(notifications, 0);
    expect(controller.selectedDetentIdentifier, 'short');
    expect(controller.targetDetentIdentifier, 'large');
    expect(first.state['selected_detent'], 'short');
    expect(first.state['target_detent'], 'large');
    expect(second.metrics, first.metrics);
    expect(second.state, first.state);
    await tester.pumpAndSettle();
    expect(controller.selectedDetentIdentifier, 'large');
    expect(selections, ['large']);
  });

  testWidgets(
    'state snapshot uses observed window points without native velocity guesses',
    (tester) async {
      await present(tester);
      final state = controller.snapshotState();
      expect(state.position, const Offset(0, 500));
      expect(state.frame.size, const Size(400, 300));
      expect(state.velocity, isNull);
      expect(state.phase, IosSheetPhase.presented);
      expect(state.selectedDetent, 'short');
      expect(state.restingDetent, 'short');
      expect(state.capabilities['motion'], IosSheetCapabilityStatus.fallback);
      expect(
        state.capabilities['corners'],
        IosSheetCapabilityStatus.unavailable,
      );
      expect(
        state.capabilities['velocity'],
        IosSheetCapabilityStatus.unavailable,
      );
      expect(state.provenance['velocity'], isNotEmpty);
    },
  );

  testWidgets(
    'overlay policy does not hide observed keyboard in state snapshot',
    (tester) async {
      await present(
        tester,
        keyboardPolicy: IosSheetKeyboardPolicy.overlay,
        media: const MediaQueryData(
          size: Size(400, 800),
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
      );
      final state = controller.snapshotState();
      expect(state.environment.observedKeyboardHeight, 300);
      expect(state.environment.appliedKeyboardAvoidance, 0);
      expect(state.environment.observedKeyboardFrame, isNull);
      expect(state.environment.horizontalSizeClass, IosSheetSizeClass.unknown);
      expect(controller.visibleHeight, 300);
    },
  );

  testWidgets('covered controller cannot accidentally dismiss the top sheet', (
    tester,
  ) async {
    await present(tester);
    final covered = controller;
    final top = IosSheetController();
    navigator.currentState!.push(
      StupidSimpleIosSheetRoute<void>(
        profile: IosSheetProfile.ios26,
        controller: top,
        child: const Center(child: Text('Top sheet')),
      ),
    );
    await tester.pumpAndSettle();
    expect(() => covered.dismiss(), throwsStateError);
    expect(find.text('Top sheet'), findsOneWidget);
    top.dismiss();
    await tester.pumpAndSettle();
    expect(covered.isAttached, isTrue);
  });

  testWidgets('uniform floating scale preserves native aspect geometry', (
    tester,
  ) async {
    await present(
      tester,
      profile: IosSheetProfile.ios26.copyWith(
        geometry: (_) => const IosSheetGeometry(scale: .9, bottomInset: 8),
        evidence: {'geometry': 'synthetic scale fixture'},
      ),
    );
    final frame = controller.captureFrame();
    expect(frame.metrics['sheet.x'], closeTo(20, .000001));
    expect(frame.metrics['sheet.y'], closeTo(522, .000001));
    expect(frame.metrics['sheet.width'], closeTo(360, .000001));
    expect(frame.metrics['sheet.height'], closeTo(270, .000001));
    expect(frame.metrics['sheet.bottom_inset'], closeTo(8, .000001));
    expect(frame.state['selected_detent'], 'short');
    expect(frame.state['underlying_hit_test'], isNull);
    expect(frame.unavailable['underlying_hit_test'], isNotEmpty);
  });

  testWidgets('fixed-surface presentation moves without resizing content', (
    tester,
  ) async {
    await present(
      tester,
      settle: false,
      profile: IosSheetProfile.ios26.copyWith(
        fixedSurfaceDuringTransition: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      controller.captureFrame().metrics['sheet.height'],
      closeTo(300, .01),
    );
    await tester.pumpAndSettle();
    expect(controller.captureFrame().metrics['sheet.y'], closeTo(500, .01));
  });

  testWidgets('custom snap physics is used for gesture target selection', (
    tester,
  ) async {
    await present(
      tester,
      profile: IosSheetProfile.ios26.copyWith(
        snapPhysics: const _LargestSnapPhysics(),
        evidence: {'snap': 'synthetic fixture'},
      ),
    );
    await tester.drag(find.text('Sheet content'), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(controller.selectedDetentIdentifier, 'large');
  });

  testWidgets('opening fixed-surface retarget rejects before changing state', (
    tester,
  ) async {
    await present(
      tester,
      settle: false,
      profile: IosSheetProfile.ios26.copyWith(
        fixedSurfaceDuringTransition: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final before = controller.captureFrame();
    expect(() => controller.selectDetent('large'), throwsStateError);
    expect(controller.selectedDetentIdentifier, 'short');
    expect(controller.targetDetentIdentifier, 'short');
    expect(
      controller.captureFrame().metrics['sheet.height'],
      before.metrics['sheet.height'],
    );
    await tester.pumpAndSettle();
    expect(controller.captureFrame().metrics['sheet.height'], 300);
    expect(controller.captureFrame().metrics['sheet.y'], 500);
  });

  testWidgets(
    'programmatic selection changes immediately while rest is absent',
    (tester) async {
      final changes = <String>[];
      await present(tester, onSelected: changes.add);
      expect(controller.restingDetentIdentifier, 'short');
      controller.selectDetent('large');
      expect(controller.selectedDetentIdentifier, 'large');
      expect(controller.requestedDetentIdentifier, 'large');
      expect(controller.targetDetentIdentifier, 'large');
      expect(controller.restingDetentIdentifier, isNull);
      expect(changes, ['large']);
      expect(controller.captureFrame().state['selected_detent'], 'large');
      await tester.pumpAndSettle();
      expect(controller.restingDetentIdentifier, 'large');
      expect(changes, ['large']);
    },
  );

  testWidgets('released gesture target synchronizes before recorder emission', (
    tester,
  ) async {
    await present(
      tester,
      profile: IosSheetProfile.ios26.copyWith(
        snapPhysics: const _LargestSnapPhysics(),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Sheet content')),
    );
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(controller.captureFrame().state['gesture'], 'touch');
    await gesture.up();
    await tester.pump();
    final frame = controller.captureFrame();
    expect(frame.state['target_detent'], 'large');
    expect(controller.targetDetentIdentifier, 'large');
    expect(controller.restingDetentIdentifier, isNull);
    expect(frame.state['gesture'], 'none');
    await tester.pumpAndSettle();
    expect(controller.restingDetentIdentifier, 'large');
  });

  testWidgets('height API separates trajectory from rendered native surface', (
    tester,
  ) async {
    await present(
      tester,
      media: const MediaQueryData(
        size: Size(402, 874),
        devicePixelRatio: 3,
        padding: EdgeInsets.only(top: 62, bottom: 34),
        viewPadding: EdgeInsets.only(top: 62, bottom: 34),
      ),
      detents: [
        IosSheetDetent.height('fixed320', 320),
        IosSheetDetent.medium,
        IosSheetDetent.large,
      ],
      initial: 'medium',
      profile: observedPage402x874Profile(26),
    );
    expect(
      controller.unscaledTrajectoryHeight,
      closeTo(469.6666666666667, .000001),
    );
    expect(
      controller.renderedSurfaceHeight,
      closeTo(450.9734660033168, .000001),
    );
    expect(
      controller.renderedVisibleHeight,
      closeTo(450.9734660033168, .000001),
    );
    expect(controller.visibleHeight, closeTo(450.9734660033168, .000001));
  });

  testWidgets('rendered visible height clips to the observed viewport', (
    tester,
  ) async {
    await present(
      tester,
      profile: IosSheetProfile.ios26.copyWith(
        geometry: (_) => const IosSheetGeometry(bottomInset: 600),
      ),
    );
    expect(controller.unscaledTrajectoryHeight, 300);
    expect(controller.renderedSurfaceHeight, 300);
    expect(controller.renderedVisibleHeight, 200);
    expect(controller.captureFrame().metrics['sheet.visible_height'], 200);
  });

  testWidgets('fitted overdrag transfer function controls real movement', (
    tester,
  ) async {
    await present(
      tester,
      profile: IosSheetProfile.ios26.copyWith(
        dragResistance: (_) => 0,
        releaseResistance: (_) => 0,
        evidence: {'overdrag': 'synthetic hard boundary fixture'},
      ),
    );
    controller.selectDetent('large');
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(controller.visibleHeight, closeTo(800, .01));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'detent-to-visible conversion includes separately measured inset',
    (tester) async {
      await present(
        tester,
        profile: IosSheetProfile.ios26.copyWith(
          maximumDetentHeight: (environment) =>
              environment.maximumDetentHeight - 20,
          detentToVisibleHeight: (height, _) => height + 20,
          evidence: {'detentGeometry': 'synthetic bottom-safe-area fixture'},
        ),
      );
      expect(controller.visibleHeight, closeTo(320, .01));
      expect(tester.getSize(find.byKey(iosSheetSurfaceKey)).height, 320);
      controller.selectDetent('large');
      await tester.pumpAndSettle();
      expect(controller.visibleHeight, 800);
    },
  );
}

class _LargestSnapPhysics extends AbsoluteSnapPhysics {
  const _LargestSnapPhysics();
  @override
  double findTargetSnapPoint({
    required double position,
    required double absoluteVelocity,
    required List<double> snapPoints,
  }) => snapPoints.last;
}
