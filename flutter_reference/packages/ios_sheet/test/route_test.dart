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
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    navigator = GlobalKey<NavigatorState>();
    controller = IosSheetController();
    backgroundTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
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
        detents: [IosSheetDetent.height('short', 300), IosSheetDetent.large],
        initialDetentIdentifier: 'short',
        largestUndimmedDetentIdentifier: undimmed,
        controller: controller,
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
