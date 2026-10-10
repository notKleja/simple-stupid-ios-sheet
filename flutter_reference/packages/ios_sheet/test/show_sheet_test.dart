import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

class _PushObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  int get pushCount => routes.length;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
  }
}

void main() {
  late BuildContext context;
  late GlobalKey<NavigatorState> root;
  late GlobalKey<NavigatorState> nested;
  late _PushObserver rootObserver;
  late _PushObserver nestedObserver;

  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    root = GlobalKey<NavigatorState>();
    nested = GlobalKey<NavigatorState>();
    rootObserver = _PushObserver();
    nestedObserver = _PushObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: root,
        navigatorObservers: [rootObserver],
        home: Navigator(
          key: nested,
          observers: [nestedObserver],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Builder(
              builder: (value) {
                context = value;
                return const Scaffold(body: Text('Home'));
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    rootObserver.routes.clear();
    nestedObserver.routes.clear();
  }

  Widget content(BuildContext context) => const Text('Sheet content');

  testWidgets('returns the exact typed pop result', (tester) async {
    await mount(tester);
    final result = Object();
    final Future<Object?> future = showIos26Sheet<Object>(
      context: context,
      builder: content,
    );
    await tester.pumpAndSettle();
    nested.currentState!.pop(result);
    await tester.pumpAndSettle();
    expect(await future, same(result));
  });

  testWidgets('defaults to the nearest nested navigator', (tester) async {
    await mount(tester);
    showIos26Sheet<void>(context: context, builder: content);
    await tester.pumpAndSettle();
    expect(nestedObserver.pushCount, 1);
    expect(rootObserver.pushCount, 0);
    expect(nestedObserver.routes.single.navigator, same(nested.currentState));
  });

  testWidgets('uses the root navigator when requested', (tester) async {
    await mount(tester);
    showIos26Sheet<void>(
      context: context,
      builder: content,
      useRootNavigator: true,
    );
    await tester.pumpAndSettle();
    expect(rootObserver.pushCount, 1);
    expect(nestedObserver.pushCount, 0);
    expect(rootObserver.routes.single.navigator, same(root.currentState));
  });

  testWidgets('preserves RouteSettings identity and builder route context', (
    tester,
  ) async {
    await mount(tester);
    final arguments = Object();
    final settings = RouteSettings(name: '/sheet', arguments: arguments);
    RouteSettings? builtSettings;
    showIos26Sheet<void>(
      context: context,
      routeSettings: settings,
      builder: (sheetContext) {
        builtSettings = ModalRoute.of(sheetContext)!.settings;
        return content(sheetContext);
      },
    );
    await tester.pumpAndSettle();
    expect(nestedObserver.routes.single.settings, same(settings));
    expect(builtSettings, same(settings));
    expect(builtSettings!.arguments, same(arguments));
    expect(builtSettings!.name, '/sheet');
  });

  testWidgets('uses the explicit iOS 26 profile and default large detent', (
    tester,
  ) async {
    await mount(tester);
    final controller = IosSheetController();
    addTearDown(controller.dispose);
    showIos26Sheet<void>(
      context: context,
      builder: content,
      controller: controller,
    );
    await tester.pumpAndSettle();
    final route = nestedObserver.routes.single as StupidSimpleIosSheetRoute;
    expect(route.profile, same(IosSheetProfile.ios26));
    expect(controller.selectedDetentIdentifier, 'large');
    expect(route.detents, [IosSheetDetent.large]);
  });

  testWidgets('forwards detents, initial selection and undimmed threshold', (
    tester,
  ) async {
    await mount(tester);
    final controller = IosSheetController();
    addTearDown(controller.dispose);
    showIos26Sheet<void>(
      context: context,
      builder: content,
      controller: controller,
      detents: [IosSheetDetent.height('short', 300), IosSheetDetent.large],
      initialDetentIdentifier: 'short',
      largestUndimmedDetentIdentifier: 'short',
    );
    await tester.pumpAndSettle();
    expect(controller.selectedDetentIdentifier, 'short');
    expect(controller.isModal, isFalse);
    expect(tester.getSize(find.byKey(iosSheetSurfaceKey)).height, 300);
    controller.selectDetent('large');
    await tester.pumpAndSettle();
    expect(controller.isModal, isTrue);
  });

  testWidgets('invokes presentation, detent and dismissal callbacks', (
    tester,
  ) async {
    await mount(tester);
    final controller = IosSheetController();
    addTearDown(controller.dispose);
    var presented = 0;
    var dismissed = 0;
    final selections = <String>[];
    showIos26Sheet<void>(
      context: context,
      builder: content,
      controller: controller,
      detents: [IosSheetDetent.height('short', 300), IosSheetDetent.large],
      initialDetentIdentifier: 'short',
      onPresented: () => presented++,
      onDismissed: () => dismissed++,
      onSelectedDetentChanged: selections.add,
    );
    await tester.pumpAndSettle();
    expect(presented, 1);
    expect(dismissed, 0);
    controller.selectDetent('large');
    await tester.pumpAndSettle();
    expect(selections, contains('large'));
    controller.dismiss();
    await tester.pumpAndSettle();
    expect(dismissed, 1);
    expect(presented, 1);
  });

  testWidgets('detaches caller-owned controller and permits reuse', (
    tester,
  ) async {
    await mount(tester);
    final controller = IosSheetController();
    addTearDown(controller.dispose);
    for (var i = 0; i < 2; i++) {
      showIos26Sheet<void>(
        context: context,
        builder: content,
        controller: controller,
      );
      await tester.pumpAndSettle();
      expect(controller.isAttached, isTrue);
      controller.dismiss();
      await tester.pumpAndSettle();
      expect(controller.isAttached, isFalse);
    }
    expect(() => controller.addListener(() {}), returnsNormally);
  });

  for (final label in <String?>[null, 'Close details']) {
    testWidgets('preserves barrier label ${label ?? 'default'}', (
      tester,
    ) async {
      await mount(tester);
      showIos26Sheet<void>(
        context: context,
        builder: content,
        barrierLabel: label,
      );
      await tester.pumpAndSettle();
      final route = nestedObserver.routes.single as StupidSimpleIosSheetRoute;
      final expected = label ?? 'Dismiss sheet';
      expect(route.barrierLabel, expected);
      final barriers = tester.widgetList<ModalBarrier>(
        find.byType(ModalBarrier),
      );
      expect(
        barriers.any((barrier) => barrier.semanticsLabel == expected),
        isTrue,
      );
      final direct = StupidSimpleIosSheetRoute<void>(
        child: const SizedBox(),
        profile: IosSheetProfile.ios26,
        barrierLabel: label,
      );
      expect(direct.barrierLabel, expected);
    });
  }

  testWidgets('forwards presentation and interaction options', (tester) async {
    await mount(tester);
    showIos26Sheet<void>(
      context: context,
      builder: content,
      contentInteraction: IosSheetContentInteraction.scrolls,
      keyboardPolicy: IosSheetKeyboardPolicy.overlay,
      draggable: false,
      dismissible: false,
      interactiveDismissDisabled: true,
      backgroundColor: CupertinoColors.black,
      modalBarrierColor: const Color(0x55010203),
    );
    await tester.pumpAndSettle();
    final route = nestedObserver.routes.single as StupidSimpleIosSheetRoute;
    expect(route.contentInteraction, IosSheetContentInteraction.scrolls);
    expect(route.keyboardPolicy, IosSheetKeyboardPolicy.overlay);
    expect(route.draggable, isFalse);
    expect(route.dismissible, isFalse);
    expect(route.interactiveDismissDisabled, isTrue);
    expect(route.backgroundColor, CupertinoColors.black);
    expect(route.modalBarrierColor, const Color(0x55010203));
    expect(route.barrierDismissible, isFalse);
  });

  testWidgets('rejects unknown initial detent synchronously before push', (
    tester,
  ) async {
    await mount(tester);
    expect(
      () => showIos26Sheet<void>(
        context: context,
        initialDetentIdentifier: 'missing',
        builder: (_) => const SizedBox(),
      ),
      throwsArgumentError,
    );
    expect(nestedObserver.pushCount, 0);
    expect(rootObserver.pushCount, 0);
  });

  testWidgets('preserves empty and unknown threshold constructor validation', (
    tester,
  ) async {
    await mount(tester);
    expect(
      () =>
          showIos26Sheet<void>(context: context, builder: content, detents: []),
      throwsArgumentError,
    );
    expect(
      () => showIos26Sheet<void>(
        context: context,
        builder: content,
        largestUndimmedDetentIdentifier: 'missing',
      ),
      throwsArgumentError,
    );
    expect(nestedObserver.pushCount, 0);
  });
}
