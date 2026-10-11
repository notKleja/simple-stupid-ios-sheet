import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Intentional direct coverage of the jointly maintained fork-private bridge.
// ignore: implementation_imports
import 'package:ios_sheet_engine/src/controller_lifecycle_bridge.dart'
    as bridge;
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

class _Probe<T> {
  _Probe(Future<T> future, {void Function()? onDone}) {
    future.then<void>(
      (result) {
        done = true;
        value = result;
        onDone?.call();
      },
      onError: (Object failure, StackTrace stack) {
        done = true;
        error = failure;
        onDone?.call();
      },
    );
  }
  bool done = false;
  T? value;
  Object? error;
}

// Observe the error where it leaves the public override; Navigator schedules
// disposal in a microtask whose uncaught errors otherwise fail the test zone.
class _FailingCallbackRoute extends StupidSimpleIosSheetRoute<Object> {
  _FailingCallbackRoute(IosSheetController controller)
    : super(
        child: const SizedBox.expand(),
        profile: IosSheetProfile.ios26,
        controller: controller,
        onDismissed: () =>
            throw StateError('expected dismissal callback failure'),
      );

  Object? failure;

  @override
  void dispose() {
    try {
      super.dispose();
    } catch (error) {
      failure = error;
    }
  }
}

// Catch the rejected public install boundary so Navigator can dispose the
// partially installed test route without leaving its debug lock held.
class _RejectedAttachmentRoute extends StupidSimpleIosSheetRoute<Object> {
  _RejectedAttachmentRoute(IosSheetController controller)
    : super(
        child: const SizedBox.expand(),
        profile: IosSheetProfile.ios26,
        controller: controller,
      );

  Object? failure;

  @override
  void install() {
    try {
      super.install();
    } catch (error) {
      failure = error;
    }
  }
}

class _Harness {
  final nav = GlobalKey<NavigatorState>();
  final sheet = IosSheetController();
  final events = <String>[];
  final pending = <bool Function()>[];
  bool controllerDisposed = false;
  late StupidSimpleIosSheetRoute<Object> route;
  late _Probe<Object?> popped;

  _Probe<T> track<T>(Future<T> future, [String? label]) {
    final probe = _Probe(
      future,
      onDone: label == null ? null : () => events.add(label),
    );
    pending.add(() => probe.done);
    return probe;
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: Text('Home')),
      ),
    );
  }

  void push({
    bool fixedOpening = false,
    VoidCallback? onPresented,
    VoidCallback? onDismissed,
  }) {
    route = StupidSimpleIosSheetRoute<Object>(
      profile: IosSheetProfile.ios26.copyWith(
        fixedSurfaceDuringTransition: fixedOpening,
      ),
      controller: sheet,
      detents: [IosSheetDetent.height('short', 300), IosSheetDetent.large],
      initialDetentIdentifier: 'short',
      onPresented: () {
        events.add('onPresented');
        onPresented?.call();
      },
      onDismissed: () {
        events.add('onDismissed');
        onDismissed?.call();
      },
      child: const ColoredBox(
        color: Colors.white,
        child: Center(child: Text('Sheet content')),
      ),
    );
    // Navigator teardown does not promise completion of its popped future.
    popped = _Probe(
      nav.currentState!.push<Object>(route),
      onDone: () => events.add('popped'),
    );
  }

  Future<void> present(WidgetTester tester) async {
    await mount(tester);
    push();
    await tester.pumpAndSettle();
    expect(sheet.restingDetentIdentifier, 'short');
    events.clear();
  }

  void disposeController() {
    sheet.dispose();
    controllerDisposed = true;
  }

  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.idle();
    expect(sheet.isAttached, isFalse);
    expect(
      pending.every((done) => done()),
      isTrue,
      reason: 'All captured lifecycle waits must be terminal',
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    if (!controllerDisposed) disposeController();
  }
}

void main() {
  testWidgets(
    'detached lifecycle calls return asynchronous error or success without binding to next attachment',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      late Future<void> presented;
      expect(() {
        presented = h.sheet.whenPresented();
      }, returnsNormally);
      final p = h.track(presented);
      final d = h.track(h.sheet.whenDetached());
      expect(p.done || d.done, isFalse);
      h.push();
      await tester.idle();
      expect(p.error, isA<StateError>());
      expect(d.done, isTrue);
      expect(d.error, isNull);
      await tester.pumpAndSettle();
      expect(p.error, isA<StateError>());
      await h.clean(tester);
    },
  );

  testWidgets(
    'opening broadcasts presentation once after callback and existing notification',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.sheet.addListener(() {
        if (h.sheet.isPresented) h.events.add('listener');
      });
      h.push(
        fixedOpening: true,
        onPresented: () => expect(h.sheet.isPresented, isTrue),
      );
      final first = h.track(h.sheet.whenPresented(), 'P1');
      final second = h.track(h.sheet.whenPresented(), 'P2');
      final detached = h.track(h.sheet.whenDetached());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(first.done || second.done || detached.done, isFalse);
      await tester.pumpAndSettle();
      expect(first.done && second.done, isTrue);
      expect(first.error ?? second.error, isNull);
      expect(h.events.where((e) => e == 'onPresented'), hasLength(1));
      expect(
        h.events.indexOf('onPresented'),
        lessThan(h.events.indexOf('listener')),
      );
      expect(h.events.indexOf('listener'), lessThan(h.events.indexOf('P1')));
      await h.clean(tester);
    },
  );

  testWidgets(
    'latched presentation completes asynchronously while moving or covered without callback replay',
    (tester) async {
      final h = _Harness();
      await h.present(tester);
      h.sheet.selectDetent('large');
      final moving = h.track(h.sheet.whenPresented());
      expect(moving.done, isFalse);
      await tester.idle();
      expect(moving.done, isTrue);
      expect(moving.error, isNull);
      await tester.pumpAndSettle();
      h.nav.currentState!
          .push<void>(
            MaterialPageRoute<void>(builder: (_) => const Text('Cover')),
          )
          .ignore();
      final covered = h.track(h.sheet.whenPresented());
      final detached = h.track(h.sheet.whenDetached());
      await tester.idle();
      expect(covered.done, isTrue);
      expect(detached.done, isFalse);
      await tester.pumpAndSettle();
      h.nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(detached.done, isFalse);
      expect(h.events, isNot(contains('onPresented')));
      await h.clean(tester);
    },
  );

  testWidgets(
    'accepted opening dismissal fails presentation before true detachment',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push();
      final p = h.track(h.sheet.whenPresented());
      final d = h.track(h.sheet.whenDetached());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(p.done, isFalse);
      h.sheet.dismiss();
      await tester.idle();
      expect(p.error, isA<StateError>());
      expect(h.sheet.isAttached, isTrue);
      expect(d.done, isFalse);
      await tester.pumpAndSettle();
      expect(d.done, isTrue);
      expect(h.events, isNot(contains('onPresented')));
      await h.clean(tester);
    },
  );

  testWidgets(
    'fixed opening rejected dismiss and pop preserve presentation wait',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(fixedOpening: true);
      final p = h.track(h.sheet.whenPresented());
      await tester.pump();
      expect(h.sheet.dismiss, throwsStateError);
      expect(h.route.didPop(null), isFalse);
      await tester.idle();
      expect(p.done, isFalse);
      await tester.pumpAndSettle();
      expect(p.done, isTrue);
      expect(p.error, isNull);
      await h.clean(tester);
    },
  );

  for (final removal in ['remove', 'replace', 'unmount']) {
    testWidgets(
      'opening $removal fails presentation and detaches only on release',
      (tester) async {
        final h = _Harness();
        await h.mount(tester);
        h.push(fixedOpening: true);
        final p = h.track(h.sheet.whenPresented());
        final d = h.track(h.sheet.whenDetached());
        await tester.pump();
        if (removal == 'remove') {
          h.nav.currentState!.removeRoute(h.route);
          expect(d.done, isFalse);
          await tester.idle();
          expect(p.error, isA<StateError>());
        } else if (removal == 'replace') {
          h.nav.currentState!
              .pushReplacement<void, Object>(
                MaterialPageRoute<void>(
                  builder: (_) => const Text('Replacement'),
                ),
                result: 'replaced',
              )
              .ignore();
          expect(d.done, isFalse);
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.pumpAndSettle();
        expect(p.error, isA<StateError>());
        expect(d.done, isTrue);
        expect(d.error, isNull);
        expect(h.events, isNot(contains('onPresented')));
        await h.clean(tester);
      },
    );
  }

  testWidgets(
    'pop result precedes disposal and detach listeners precede onDismissed and future observers',
    (tester) async {
      final h = _Harness();
      await h.present(tester);
      final d = h.track(h.sheet.whenDetached(), 'detached');
      h.sheet.addListener(() {
        if (!h.sheet.isAttached) h.events.add('detach-listener');
      });
      final token = Object();
      h.sheet.dismiss(token);
      await tester.idle();
      expect(h.popped.done, isTrue);
      expect(h.popped.value, same(token));
      expect(d.done, isFalse);
      expect(h.sheet.isAttached, isTrue);
      await tester.pumpAndSettle();
      expect(d.done, isTrue);
      expect(
        h.events.indexOf('detach-listener'),
        lessThan(h.events.indexOf('onDismissed')),
      );
      expect(
        h.events.indexOf('onDismissed'),
        lessThan(h.events.indexOf('detached')),
      );
      await h.clean(tester);
    },
  );

  testWidgets(
    'detach observers can safely reuse the controller and old events cannot settle the new generation',
    (tester) async {
      final h = _Harness();
      await h.present(tester);
      final oldRoute = h.route;
      final oldDetached = h.track(h.sheet.whenDetached());
      late _Probe<void> nextPresented;
      h.sheet.whenDetached().then((_) {
        h.push(fixedOpening: true);
        nextPresented = h.track(h.sheet.whenPresented());
      });
      h.sheet.dismiss();
      await tester.pumpAndSettle();
      expect(oldDetached.done, isTrue);
      expect(nextPresented.done, isTrue);
      expect(nextPresented.error, isNull);
      expect(h.sheet.isAttached, isTrue);
      bridge.dispatchSheetDragEnd(oldRoute);
      bridge.dispatchSheetDragCancel(oldRoute);
      expect(oldDetached.error, isNull);
      final freshDetached = h.track(h.sheet.whenDetached());
      await tester.idle();
      expect(freshDetached.done, isFalse);
      h.sheet.dismiss();
      await tester.pumpAndSettle();
      expect(freshDetached.done, isTrue);
      await h.clean(tester);
    },
  );

  testWidgets('old failed presentation cannot rebind across controller reuse', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    h.push(fixedOpening: true);
    final oldRoute = h.route;
    final oldP = h.track(h.sheet.whenPresented());
    final oldD = h.track(h.sheet.whenDetached());
    await tester.pump();
    h.nav.currentState!.removeRoute(oldRoute);
    await tester.pumpAndSettle();
    h.push(fixedOpening: true);
    final freshP = h.track(h.sheet.whenPresented());
    bridge.dispatchSheetDragEnd(oldRoute);
    await tester.idle();
    expect(freshP.done, isFalse);
    expect(oldP.error, isA<StateError>());
    expect(oldD.done, isTrue);
    await tester.pumpAndSettle();
    expect(freshP.done, isTrue);
    expect(freshP.error, isNull);
    await h.clean(tester);
  });

  testWidgets(
    'attached controller disposal fails waits and leaves Navigator ownership without late notifications',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(fixedOpening: true);
      final p = h.track(h.sheet.whenPresented());
      final d = h.track(h.sheet.whenDetached());
      await tester.pump();
      h.disposeController();
      expect(h.sheet.isAttached, isFalse);
      expect(h.sheet.isPresented, isFalse);
      expect(h.sheet.selectedDetentIdentifier, isNull);
      expect(h.sheet.renderedSurfaceHeight, 0);
      late Future<void> afterP;
      expect(() {
        afterP = h.sheet.whenPresented();
      }, returnsNormally);
      final disposedP = h.track(afterP);
      final disposedD = h.track(h.sheet.whenDetached());
      expect(p.done || d.done || disposedP.done || disposedD.done, isFalse);
      await tester.idle();
      for (final probe in [p, d, disposedP, disposedD]) {
        expect(probe.error, isA<StateError>());
      }
      bridge.dispatchSheetDragEnd(h.route);
      bridge.dispatchSheetDragCancel(h.route);
      await tester.pumpAndSettle();
      expect(h.route.isCurrent, isTrue);
      h.nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await h.clean(tester);
    },
  );

  testWidgets(
    'disposed detached calls fail asynchronously without revoking a completed detach',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      final completed = h.track(h.sheet.whenDetached());
      await tester.idle();
      h.disposeController();
      final p = h.track(h.sheet.whenPresented());
      final d = h.track(h.sheet.whenDetached());
      expect(p.done || d.done, isFalse);
      await tester.idle();
      expect(p.error, isA<StateError>());
      expect(d.error, isA<StateError>());
      expect(completed.done, isTrue);
      expect(completed.error, isNull);
      await h.clean(tester);
    },
  );

  testWidgets(
    'onPresented immediate dismissal preserves latched presentation',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(onPresented: () => h.sheet.dismiss());
      final p = h.track(h.sheet.whenPresented());
      final d = h.track(h.sheet.whenDetached());
      await tester.pumpAndSettle();
      expect(p.done && d.done, isTrue);
      expect(p.error ?? d.error, isNull);
      await h.clean(tester);
    },
  );

  testWidgets(
    'throwing onDismissed still settles detach and tears down the engine',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      final route = _FailingCallbackRoute(h.sheet);
      h.route = route;
      h.popped = _Probe(h.nav.currentState!.push<Object>(route));
      await tester.pumpAndSettle();
      final d = h.track(h.sheet.whenDetached());
      h.sheet.dismiss();
      await tester.pumpAndSettle();
      expect(
        route.failure,
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'expected dismissal callback failure',
        ),
      );
      expect(d.done, isTrue);
      expect(d.error, isNull);
      await h.clean(tester);
    },
  );

  testWidgets(
    'rejected disposal inside notify leaves controller attachment and waits intact',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      var attempted = false;
      Object? failure;
      h.sheet.addListener(() {
        if (h.sheet.isPresented && !attempted) {
          attempted = true;
          try {
            h.sheet.dispose();
          } catch (error) {
            failure = error;
          }
        }
      });
      h.push(fixedOpening: true);
      final p = h.track(h.sheet.whenPresented());
      final d = h.track(h.sheet.whenDetached());
      await tester.pumpAndSettle();
      expect(failure, isA<AssertionError>());
      expect(h.sheet.isAttached, isTrue);
      expect(p.error, isNull);
      expect(d.done, isFalse);
      h.sheet.dismiss();
      await tester.pumpAndSettle();
      expect(d.error, isNull);
      await h.clean(tester);
    },
  );

  testWidgets('a declined superclass pop does not mark presentation removed', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    h.push();
    final p = h.track(h.sheet.whenPresented());
    final d = h.track(h.sheet.whenDetached());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    h.route.addLocalHistoryEntry(LocalHistoryEntry());
    h.nav.currentState!.pop();
    await tester.idle();
    expect(h.popped.done, isFalse);
    expect(p.done || d.done, isFalse);
    expect(h.sheet.isAttached, isTrue);
    h.sheet.selectDetent('short');
    await tester.pumpAndSettle();
    expect(p.done, isTrue);
    expect(p.error, isNull);
    await h.clean(tester);
  });

  testWidgets(
    'nonopaque coverage permits first presentation without detachment',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(fixedOpening: true);
      final p = h.track(h.sheet.whenPresented());
      final d = h.track(h.sheet.whenDetached());
      await tester.pump();
      h.nav.currentState!
          .push<void>(
            PageRouteBuilder<void>(
              opaque: false,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, animation, secondaryAnimation) =>
                  const SizedBox.shrink(),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      expect(h.route.isCurrent, isFalse);
      expect(h.sheet.isPresented, isTrue);
      expect(p.done, isTrue);
      expect(p.error, isNull);
      expect(d.done, isFalse);
      h.nav.currentState!.removeRoute(h.route);
      await tester.pumpAndSettle();
      expect(d.done, isTrue);
      expect(p.error, isNull);
      await h.clean(tester);
    },
  );

  for (final exiting in [false, true]) {
    testWidgets(
      'controller disposal after presentation${exiting ? ' during exit' : ''} fails only detachment',
      (tester) async {
        final h = _Harness();
        await h.present(tester);
        final p = h.track(h.sheet.whenPresented());
        final d = h.track(h.sheet.whenDetached());
        if (exiting) h.sheet.dismiss();
        h.disposeController();
        await tester.idle();
        expect(p.done, isTrue);
        expect(p.error, isNull);
        expect(d.error, isA<StateError>());
        await tester.pumpAndSettle();
        if (!exiting) {
          h.nav.currentState!.pop();
          await tester.pumpAndSettle();
        }
        await h.clean(tester);
      },
    );
  }

  testWidgets(
    'unobserved opening removal creates no failed future or leaked ticker',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(fixedOpening: true);
      await tester.pump();
      h.nav.currentState!.removeRoute(h.route);
      await tester.pumpAndSettle();
      await h.clean(tester);
    },
  );

  testWidgets(
    'failed double attachment preserves the original generation and its waits',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(fixedOpening: true);
      final original = h.route;
      final p = h.track(h.sheet.whenPresented());
      final d = h.track(h.sheet.whenDetached());
      final rejected = _RejectedAttachmentRoute(h.sheet);
      h.nav.currentState!.push<Object>(rejected).ignore();
      expect(rejected.failure, isA<StateError>());
      expect(h.sheet.selectedDetentIdentifier, 'short');
      expect(p.done || d.done, isFalse);
      h.nav.currentState!.removeRoute(rejected);
      await tester.pumpAndSettle();
      expect(h.route, same(original));
      expect(h.sheet.isAttached, isTrue);
      expect(p.done, isTrue);
      expect(p.error, isNull);
      expect(d.done, isFalse);
      await h.clean(tester);
    },
  );

  testWidgets('a disposed controller rejects a later attachment', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    h.disposeController();
    final rejected = _RejectedAttachmentRoute(h.sheet);
    h.nav.currentState!.push<Object>(rejected).ignore();
    expect(rejected.failure, isA<StateError>());
    expect(h.sheet.isAttached, isFalse);
    await tester.pumpAndSettle();
    await h.clean(tester);
  });

  testWidgets(
    'bridge observations introduce no extra controller notifications',
    (tester) async {
      final h = _Harness();
      await h.present(tester);
      var notifications = 0;
      h.sheet.addListener(() => notifications++);
      final before = notifications;
      bridge.dispatchSheetDragStart(h.route);
      bridge.dispatchSheetDragEnd(h.route);
      bridge.dispatchSheetDragCancel(h.route);
      expect(notifications, before);
      await h.clean(tester);
    },
  );
}
