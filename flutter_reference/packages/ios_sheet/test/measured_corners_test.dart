import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  const env = IosSheetEnvironment(
    availableSize: Size(402, 874),
    maximumDetentHeight: 778,
    safeArea: EdgeInsets.only(top: 62, bottom: 34),
    displayScale: 3,
    orientation: IosSheetOrientation.portrait,
    observedKeyboardHeight: 0,
  );
  // Literal transformed top fixtures; expected values evaluated independently.
  const fixtures = [
    (
      name: 'fixed320',
      height: 354.0,
      top: 526.089552238806,
      bottom: 54.193639596037016,
      frame: Rect.fromLTWH(8, 526.089552238806, 386, 339.91044776119406),
    ),
    (
      name: 'medium',
      height: 1409 / 3,
      top: 415.0265339966832,
      bottom: 56.089992288540984,
      frame: Rect.fromLTWH(8, 415.0265339966832, 386, 450.9734660033168),
    ),
    (
      name: 'large',
      height: 812.0,
      top: 62.0,
      bottom: 62.11776668965163,
      frame: Rect.fromLTWH(0, 62, 402, 812),
    ),
    (
      name: 'intermediate',
      height: 600.0,
      top: 282.22830346805404,
      bottom: 58.35746426984191,
      frame: Rect.fromLTWH(
        4.954235637779942,
        282.22830346805404,
        392.09152872444014,
        585.2112369021495,
      ),
    ),
  ];
  for (final fixture in fixtures) {
    test('${fixture.name} uses four separate model radii from final top', () {
      // ignore: deprecated_member_use_from_same_package
      final geometry = observedPage402x874Profile(26).geometry(
        IosSheetGeometryContext(
          environment: env,
          visibleHeight: fixture.height,
          progress: fixture.height / 812,
        ),
      );
      expect(geometry.shape, isA<RoundedSuperellipseBorder>());
      final border = geometry.shape! as RoundedSuperellipseBorder;
      final radii = border.borderRadius.resolve(TextDirection.ltr);
      expect(radii.topLeft.x, 38);
      expect(radii.topRight.x, 38);
      expect(radii.bottomRight.x, closeTo(fixture.bottom, 1e-10));
      expect(radii.bottomLeft.x, closeTo(fixture.bottom, 1e-10));
    });
  }

  test(
    'synchronous resolver uses literal tops and immutable model provenance',
    () {
      const model = IosSheetPage402x874CornerModel(majorVersion: 26);
      expect(model.minimumTop, 62);
      expect(model.maximumTop, 874);
      for (final fixture in fixtures) {
        final result = model.resolve(
          IosSheetCornerRequest(environment: env, frame: fixture.frame),
        );
        expect(result.status, IosSheetCornerStatus.resolved);
        expect(result.radii!.clockwise.map((radius) => radius.x), [
          38,
          38,
          closeTo(fixture.bottom, 1e-10),
          closeTo(fixture.bottom, 1e-10),
        ]);
        expect(result.provenance, contains('164ab02e'));
        expect(result.provenance, contains('contour unresolved'));
      }
    },
  );

  test('resolver never extrapolates or applies iOS26 bottoms to iOS27', () {
    const model = IosSheetPage402x874CornerModel(majorVersion: 26);
    for (final top in [61.99, 874.01, double.nan, double.infinity]) {
      final result = model.resolve(
        IosSheetCornerRequest(
          environment: env,
          frame: Rect.fromLTWH(8, top, 386, 400),
        ),
      );
      expect(result.status, IosSheetCornerStatus.unavailable);
      expect(result.radii, isNull);
      expect(result.reason, isNotEmpty);
    }
    final unsupported = model.resolve(
      const IosSheetCornerRequest(
        environment: IosSheetEnvironment(
          availableSize: Size(430, 932),
          maximumDetentHeight: 800,
          displayScale: 3,
          orientation: IosSheetOrientation.portrait,
        ),
        frame: Rect.fromLTWH(8, 415, 414, 400),
      ),
    );
    expect(unsupported.status, IosSheetCornerStatus.unavailable);
    final ios27 = const IosSheetPage402x874CornerModel(majorVersion: 27)
        .resolve(
          const IosSheetCornerRequest(
            environment: env,
            frame: Rect.fromLTWH(8, 415, 386, 400),
          ),
        );
    expect(ios27.status, IosSheetCornerStatus.unavailable);
    expect(ios27.radii, isNull);
    expect(ios27.reason, contains('iOS27'));
  });

  test(
    'full recorded frame domains reject invalid and sub-fixed320 surfaces',
    () {
      const model = IosSheetPage402x874CornerModel(majorVersion: 26);
      const invalid = [
        Rect.fromLTWH(
          8,
          700,
          386,
          100,
        ), // Below recorded fixed320 visible height.
        Rect.fromLTWH(8, 415, 350, 451), // Width below recorded domain.
        Rect.fromLTWH(0, 62, 403, 812), // Width above recorded domain.
        Rect.fromLTWH(8, 415, 386, 813), // Height above recorded domain.
        Rect.fromLTWH(0, 415, 402, 450), // Bottom inset9 exceeds recorded8.
        Rect.fromLTWH(
          8,
          874,
          386,
          451,
        ), // Bottom beyond negative opening limit.
        Rect.fromLTWH(
          9,
          415,
          384,
          451,
        ), // Both side insets9 exceed recorded limit.
        Rect.fromLTWH(-1, 415, 386, 451),
        Rect.fromLTWH(double.nan, 415, 386, 451),
        Rect.fromLTWH(8, 415, double.nan, 451),
        Rect.fromLTWH(8, 415, 386, double.infinity),
        Rect.fromLTWH(8, 415, 0, 451),
        Rect.fromLTWH(8, 415, 386, -1),
      ];
      for (final frame in invalid) {
        final result = model.resolve(
          IosSheetCornerRequest(environment: env, frame: frame),
        );
        expect(
          result.status,
          IosSheetCornerStatus.unavailable,
          reason: '$frame',
        );
        expect(result.radii, isNull);
        expect(result.reason, isNotEmpty);
      }
      // ignore: deprecated_member_use_from_same_package
      final belowFixed = observedPage402x874Profile(26).geometry(
        const IosSheetGeometryContext(
          environment: env,
          visibleHeight: 134,
          progress: 134 / 812,
        ),
      );
      expect(
        belowFixed.cornerResolution!.status,
        IosSheetCornerStatus.unavailable,
      );
      expect(belowFixed.shape, isNull);
    },
  );

  test(
    'recorded frame-domain endpoints include opening and largest surface',
    () {
      const model = IosSheetPage402x874CornerModel(majorVersion: 26);
      for (final frame in [
        fixtures.first.frame,
        const Rect.fromLTWH(0, 62, 402, 812),
        const Rect.fromLTWH(8, 874, 386, 450.97346600331684),
      ]) {
        expect(
          model
              .resolve(IosSheetCornerRequest(environment: env, frame: frame))
              .status,
          IosSheetCornerStatus.resolved,
        );
      }
    },
  );

  test(
    'opening translation contributes to model top without a detent-name rule',
    () {
      // ignore: deprecated_member_use_from_same_package
      final geometry = observedPage402x874Profile(26).geometry(
        const IosSheetGeometryContext(
          environment: env,
          visibleHeight: 1409 / 3,
          progress: 1409 / 2436,
          transitionFraction: 0,
        ),
      );
      expect(
        geometry.cornerResolution!.radii!.bottomLeft.x,
        closeTo(48.253220140445695, 1e-10),
      ); // Literal top874 boundary.
      // ignore: deprecated_member_use_from_same_package
      final outOfDomain = observedPage402x874Profile(26).geometry(
        const IosSheetGeometryContext(
          environment: env,
          visibleHeight: 900,
          progress: 900 / 812,
        ),
      );
      expect(
        outOfDomain.cornerResolution!.status,
        IosSheetCornerStatus.unavailable,
      );
      expect(outOfDomain.shape, isNull); // Existing visibly marked24 fallback.
    },
  );

  Future<IosSheetController> present(WidgetTester tester, int version) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigator = GlobalKey<NavigatorState>();
    final controller = IosSheetController();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(402, 874),
            devicePixelRatio: 3,
            padding: EdgeInsets.only(top: 62, bottom: 34),
            viewPadding: EdgeInsets.only(top: 62, bottom: 34),
          ),
          child: child!,
        ),
        home: const Scaffold(body: Text('Presenter')),
      ),
    );
    navigator.currentState!.push(
      StupidSimpleIosSheetRoute<void>(
        // ignore: deprecated_member_use_from_same_package
        profile: observedPage402x874Profile(version),
        controller: controller,
        detents: [
          IosSheetDetent.height('fixed320', 320),
          IosSheetDetent.medium,
          IosSheetDetent.large,
        ],
        initialDetentIdentifier: 'medium',
        child: const Center(child: Text('Corner surface')),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets(
    'real route paint clip hit path and trace share four model corners',
    (tester) async {
      final controller = await present(tester, 26);
      final surface = tester.widget<DecoratedBox>(
        find.byKey(iosSheetSurfaceKey),
      );
      final decoration = surface.decoration as ShapeDecoration;
      final clip = tester.widget<ClipPath>(
        find
            .descendant(
              of: find.byKey(iosSheetSurfaceKey),
              matching: find.byType(ClipPath),
            )
            .first,
      );
      final clipper = clip.clipper! as ShapeBorderClipper;
      expect(identical(decoration.shape, clipper.shape), isTrue);
      final frame = controller.captureFrame();
      expect(frame.metrics['sheet.radius.top_left'], 38);
      expect(frame.metrics['sheet.radius.top_right'], 38);
      expect(
        frame.metrics['sheet.radius.bottom_right'],
        closeTo(56.089992288540984, 1e-10),
      );
      expect(
        frame.metrics['sheet.radius.bottom_left'],
        closeTo(56.089992288540984, 1e-10),
      );
      expect(frame.metrics['sheet.radius'], isNull);
      expect(
        frame.implementationProvenance['rendered_contour_status'],
        'unavailable',
      );
      final render = tester.renderObject<RenderClipPath>(
        find
            .descendant(
              of: find.byKey(iosSheetSurfaceKey),
              matching: find.byType(ClipPath),
            )
            .first,
      );
      final path = clipper.getClip(render.size);
      expect(path.contains(const Offset(1, 1)), isFalse);
      expect(
        render.hitTest(BoxHitTestResult(), position: const Offset(1, 1)),
        isFalse,
      );
      expect(path.contains(render.size.center(Offset.zero)), isTrue);
      expect(
        render.hitTest(
          BoxHitTestResult(),
          position: render.size.center(Offset.zero),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'trace stays tied to last layout then updates at real intermediate top',
    (tester) async {
      final controller = await present(tester, 26);
      final route =
          ModalRoute.of(tester.element(find.text('Corner surface')))!
              as StupidSimpleIosSheetRoute<void>;
      // ignore: invalid_use_of_protected_member
      final engine = route.controller!;
      engine.value = 600 / 812;
      // A live engine update has not repainted or relaid out this surface yet.
      expect(
        controller.captureFrame().metrics['sheet.radius.bottom_left'],
        closeTo(56.089992288540984, 1e-10),
      );
      await tester.pump();
      final intermediate = controller.captureFrame();
      expect(
        intermediate.metrics['sheet.y'],
        closeTo(282.22830346805404, 1e-10),
      );
      expect(
        intermediate.metrics['sheet.radius.bottom_left'],
        closeTo(58.35746426984191, 1e-10),
      );
      for (final fixture in fixtures.take(3)) {
        controller.selectDetent(fixture.name);
        await tester.pumpAndSettle();
        final frame = controller.captureFrame();
        expect(frame.metrics['sheet.y'], closeTo(fixture.top, 1e-10));
        expect(frame.metrics['sheet.radius.top_left'], 38);
        expect(frame.metrics['sheet.radius.top_right'], 38);
        expect(
          frame.metrics['sheet.radius.bottom_left'],
          closeTo(fixture.bottom, 1e-10),
        );
        expect(
          frame.metrics['sheet.radius.bottom_right'],
          closeTo(fixture.bottom, 1e-10),
        );
        expect(frame.metrics['sheet.radius'], isNull);
      }
    },
  );

  testWidgets(
    'build-only and layout-only captures retain one completed painted frame',
    (tester) async {
      final controller = await present(tester, 26);
      final before = controller.captureFrame();
      final route =
          ModalRoute.of(tester.element(find.text('Corner surface')))!
              as StupidSimpleIosSheetRoute<void>;
      // ignore: invalid_use_of_protected_member
      route.controller!.value = 600 / 812;
      try {
        await tester.pump(Duration.zero, EnginePhase.build);
        final built = controller.captureFrame();
        expect(built.metrics['sheet.y'], before.metrics['sheet.y']);
        expect(built.metrics['sheet.height'], before.metrics['sheet.height']);
        expect(
          built.metrics['sheet.radius.bottom_left'],
          before.metrics['sheet.radius.bottom_left'],
        );
        tester.binding.scheduleFrame();
        await tester.pump(Duration.zero, EnginePhase.layout);
        final laidOut = controller.captureFrame();
        expect(laidOut.metrics['sheet.y'], before.metrics['sheet.y']);
        expect(laidOut.metrics['sheet.height'], before.metrics['sheet.height']);
        expect(
          laidOut.metrics['sheet.radius.bottom_left'],
          before.metrics['sheet.radius.bottom_left'],
        );
        tester.binding.scheduleFrame();
        await tester.pump();
        final painted = controller.captureFrame();
        expect(painted.metrics['sheet.y'], closeTo(282.22830346805404, 1e-10));
        expect(
          painted.metrics['sheet.radius.bottom_left'],
          closeTo(58.35746426984191, 1e-10),
        );
      } finally {
        // Complete any deliberately paused render pipeline before teardown.
        tester.binding.scheduleFrame();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'iOS27 corners stay unavailable with explicitly marked fallback',
    (tester) async {
      final controller = await present(tester, 27);
      final frame = controller.captureFrame();
      for (final corner in [
        'top_left',
        'top_right',
        'bottom_right',
        'bottom_left',
      ]) {
        expect(frame.metrics['sheet.radius.$corner'], isNull);
        expect(frame.unavailable['sheet.radius.$corner'], contains('iOS27'));
      }
      expect(frame.implementationProvenance['corner_fallback'], contains('24'));
      expect(
        frame.implementationProvenance['rendered_contour_status'],
        'unavailable',
      );
    },
  );
}
