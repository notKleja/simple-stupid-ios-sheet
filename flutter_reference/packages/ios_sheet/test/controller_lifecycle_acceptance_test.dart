import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

// Public contract acceptance, frozen from the approved lifecycle design.
// These synthetic host tests do not establish paint receipt or native parity.
void main() {
  _case('L01 detached waits deliver asynchronously and never rebind', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    late Future<void> future;
    expect(() => future = h.sheet.whenPresented(), returnsNormally);
    final p = h.track(future);
    final d = h.track(h.sheet.whenDetached());
    expect(p.done, isFalse);
    expect(d.done, isFalse);
    h.push();
    await tester.idle();
    expect(p.error, isA<StateError>());
    expect(d.done, isTrue);
    expect(d.error, isNull);
    await tester.pumpAndSettle();
    expect(h.sheet.isPresented, isTrue);
    expect(p.error, isA<StateError>());
    expect(d.completions, 1);
  });

  _case('L02 opening broadcasts waits in callback listener observer order', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    h.sheet.addListener(() {
      if (h.sheet.isPresented) h.events.add('presented-listener');
    });
    h.push(
      fixedOpening: true,
      onPresented: () => expect(h.sheet.isPresented, isTrue),
    );
    final p1 = h.track(h.sheet.whenPresented(), 'P1');
    final p2 = h.track(h.sheet.whenPresented(), 'P2');
    final d1 = h.track(h.sheet.whenDetached());
    final d2 = h.track(h.sheet.whenDetached());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.sheet.isPresented, isFalse);
    expect([p1.done, p2.done, d1.done, d2.done], everyElement(isFalse));
    await tester.pumpAndSettle();
    _success(p1);
    _success(p2);
    _before(h.events, 'onPresented', 'presented-listener');
    _before(h.events, 'presented-listener', 'P1');
    _before(h.events, 'presented-listener', 'P2');
    expect(h.events.where((event) => event == 'onPresented'), hasLength(1));
    expect(p1.completions, 1);
    expect(p2.completions, 1);
    expect(d1.done || d2.done, isFalse);
  });

  _case('L03 latched presentation needs no frame or callback replay', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final p = h.track(h.sheet.whenPresented(), 'P');
    expect(p.done, isFalse);
    expect(h.events, isEmpty);
    await tester.idle();
    _success(p);
    expect(h.events, ['P']);
    final a = h.track(h.sheet.animateToDetent('large'));
    final moving = h.track(h.sheet.whenPresented());
    await tester.idle();
    _success(moving);
    expect(a.done, isFalse);
    await tester.pumpAndSettle();
    expect(a.value, isTrue);
    h.sheet.dismiss();
    final dismissing = h.track(h.sheet.whenPresented());
    await tester.idle();
    _success(dismissing);
    expect(h.sheet.isAttached, isTrue);
  });

  _case('L04 accepted opening dismiss fails P at logical completion', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    h.push();
    final p = h.track(h.sheet.whenPresented());
    final d = h.track(h.sheet.whenDetached());
    await tester.pump();
    expect(h.sheet.isPresented, isFalse);
    h.sheet.dismiss();
    expect(p.done, isFalse);
    await tester.idle();
    expect(p.error, isA<StateError>());
    expect(d.done, isFalse);
    expect(h.sheet.isAttached, isTrue);
    expect(h.events, isNot(contains('onPresented')));
    await tester.pumpAndSettle();
    _success(d);
  });

  _case('L04 fixed opening rejects commands and pop without failing waits', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    h.push(fixedOpening: true);
    final p = h.track(h.sheet.whenPresented());
    final d = h.track(h.sheet.whenDetached());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final request = h.sheet.snapshotState().motionRequest;
    expect(() => h.sheet.animateToDetent('large'), throwsStateError);
    expect(() => h.sheet.selectDetent('large'), throwsStateError);
    expect(() => h.sheet.dismiss(), throwsStateError);
    h.nav.currentState!.pop();
    await tester.idle();
    expect(p.done || d.done, isFalse);
    expect(h.sheet.snapshotState().motionRequest, same(request));
    expect(h.sheet.selectedDetentIdentifier, 'short');
    await tester.pumpAndSettle();
    _success(p);
    expect(d.done, isFalse);
  });

  for (final removal in _Removal.values) {
    _case('L05 opening ${removal.name} fails P and releases D', (
      tester,
      h,
    ) async {
      await h.mount(tester);
      h.push(fixedOpening: true);
      final p = h.track(h.sheet.whenPresented());
      final d = h.track(h.sheet.whenDetached());
      await tester.pump();
      expect(p.done, isFalse);
      await h.remove(tester, removal);
      expect(p.error, isA<StateError>());
      _success(d);
      expect(h.events, isNot(contains('onPresented')));
      expect(h.events.where((event) => event == 'onDismissed'), hasLength(1));
    });
  }

  _case('L06 pop result precedes detach and synchronous teardown callbacks', (
    tester,
    h,
  ) async {
    await h.present(tester);
    h.sheet.addListener(() {
      if (!h.sheet.isAttached) h.events.add('detach-listener');
    });
    final d1 = h.track(h.sheet.whenDetached(), 'D1');
    final d2 = h.track(h.sheet.whenDetached(), 'D2');
    final token = Object();
    h.sheet.dismiss(token);
    expect(h.sheet.isAttached, isTrue);
    expect(d1.done || d2.done, isFalse);
    await tester.idle();
    expect(h.popped.done, isTrue);
    expect(h.popped.value, same(token));
    expect(h.sheet.isAttached, isTrue);
    expect(d1.done || d2.done, isFalse);
    await tester.pumpAndSettle();
    _success(d1);
    _success(d2);
    _before(h.events, 'detach-listener', 'onDismissed');
    _before(h.events, 'onDismissed', 'D1');
    _before(h.events, 'onDismissed', 'D2');
  });

  _case('L07 awaited detachment supports repeated generation reuse', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    for (var generation = 0; generation < 3; generation++) {
      h.push(
        onDismissed: () {
          expect(h.sheet.isAttached, isFalse);
          expect(h.sheet.isPresented, isFalse);
        },
      );
      final p = h.track(h.sheet.whenPresented());
      await tester.pumpAndSettle();
      _success(p);
      final d = h.track(h.sheet.whenDetached());
      h.sheet.dismiss();
      await tester.pumpAndSettle();
      _success(d);
      await d.future;
      expect(h.sheet.isAttached, isFalse);
      expect(p.completions, 1);
    }
    expect(h.events.where((event) => event == 'onDismissed'), hasLength(3));
    expect(() => h.sheet.addListener(() {}), returnsNormally);
  });

  _case('L07 detach observer can push a new attachment', (tester, h) async {
    await h.present(tester);
    var reattached = false;
    final d = h.track(h.sheet.whenDetached(), null, () {
      expectSync(h.sheet.isAttached, isFalse);
      h.push();
      reattached = true;
    });
    h.sheet.dismiss();
    await tester.pumpAndSettle();
    _success(d);
    expect(reattached, isTrue);
    expect(h.sheet.isAttached, isTrue);
    final p = h.track(h.sheet.whenPresented());
    await tester.idle();
    _success(p);
    expect(d.completions, 1);
  });

  _case('L07 failed double attachment preserves original waits', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    h.push(fixedOpening: true);
    final p = h.track(h.sheet.whenPresented());
    final d = h.track(h.sheet.whenDetached());
    final duplicate = _InstallOnlyRoute(h.nav.currentState!, h.sheet);
    // Install is the attachment boundary. Avoid leaving a failed push in the
    // Navigator history; dispose releases the duplicate's allocated resources.
    expect(() => duplicate.install(), throwsStateError);
    duplicate.dispose();
    await tester.pumpAndSettle();
    _success(p);
    expect(d.done, isFalse);
    expect(h.sheet.selectedDetentIdentifier, 'short');
  });

  _case('L08 cover uncover and removing a covered route capture detachment', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final d = h.track(h.sheet.whenDetached());
    h.cover();
    await tester.pumpAndSettle();
    expect(h.sheet.isAttached, isTrue);
    expect(d.done, isFalse);
    final p = h.track(h.sheet.whenPresented());
    await tester.idle();
    _success(p);
    h.nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(d.done, isFalse);
    h.cover();
    await tester.pumpAndSettle();
    final token = Object();
    h.nav.currentState!.removeRoute(h.route, token);
    await tester.pumpAndSettle();
    _success(d);
    expect(h.popped.value, same(token));
    expect(find.text('Cover'), findsOneWidget);
  });

  _case('L08 typed replacement returns its token before eventual detach', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final d = h.track(h.sheet.whenDetached());
    final token = Object();
    h.nav.currentState!.pushReplacement<void, Object>(
      MaterialPageRoute<void>(builder: (_) => const Text('Replacement')),
      result: token,
    );
    expect(d.done, isFalse);
    await tester.pumpAndSettle();
    _success(d);
    expect(h.popped.done, isTrue);
    expect(h.popped.value, same(token));
  });

  _case('L09 nonopaque coverage permits attachment presentation', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    h.push(fixedOpening: true);
    final p = h.track(h.sheet.whenPresented());
    final d = h.track(h.sheet.whenDetached());
    await tester.pump();
    h.cover(opaque: false);
    await tester.pumpAndSettle();
    expect(h.route.isCurrent, isFalse);
    _success(p);
    expect(h.sheet.isPresented, isTrue);
    expect(d.done, isFalse);
  });

  _case('L09 opaque cover may defer P until uncover but cannot detach', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    h.push(fixedOpening: true);
    final p = h.track(h.sheet.whenPresented());
    final d = h.track(h.sheet.whenDetached());
    await tester.pump();
    h.cover();
    await tester.pumpAndSettle();
    expect(p.error, isNull);
    expect(d.done, isFalse);
    h.nav.currentState!.pop();
    await tester.pumpAndSettle();
    _success(p);
    expect(d.done, isFalse);
  });

  for (final phase in ['opening', 'rest', 'exit']) {
    _case('L10 L11 owner disposal during $phase abandons waits not route', (
      tester,
      h,
    ) async {
      await h.mount(tester);
      h.push(fixedOpening: phase == 'opening');
      final p = h.track(h.sheet.whenPresented());
      if (phase == 'opening') {
        await tester.pump();
      } else {
        await tester.pumpAndSettle();
      }
      final d = h.track(h.sheet.whenDetached());
      final a = phase == 'rest'
          ? h.track(h.sheet.animateToDetent('large'))
          : null;
      if (phase == 'exit') h.sheet.dismiss();
      var notifications = 0;
      h.sheet.addListener(() => notifications++);
      h.disposeController();
      expect(h.sheet.isAttached, isFalse);
      expect(h.sheet.isPresented, isFalse);
      expect(h.sheet.selectedDetentIdentifier, isNull);
      expect(h.sheet.targetDetentIdentifier, isNull);
      expect(h.sheet.restingDetentIdentifier, isNull);
      expect(h.sheet.unscaledTrajectoryHeight, 0);
      expect(h.sheet.visibleHeight, 0);
      expect(h.sheet.isModal, isFalse);
      await tester.idle();
      expect(d.error, isA<StateError>());
      if (phase == 'opening') {
        expect(p.error, isA<StateError>());
      } else {
        _success(p);
      }
      if (a != null) expect(a.value, isFalse);
      late Future<void> afterP;
      late Future<void> afterD;
      expect(() => afterP = h.sheet.whenPresented(), returnsNormally);
      expect(() => afterD = h.sheet.whenDetached(), returnsNormally);
      final disposedP = h.track(afterP);
      final disposedD = h.track(afterD);
      expect(() => h.sheet.animateToDetent('large'), throwsStateError);
      await tester.idle();
      expect(disposedP.error, isA<StateError>());
      expect(disposedD.error, isA<StateError>());
      await tester.pumpAndSettle();
      expect(notifications, 0);
      if (phase != 'exit') {
        expect(h.route.isActive, isTrue);
        h.nav.currentState!.pop();
        await tester.pumpAndSettle();
      }
      expect(h.popped.done, isTrue);
      expect(notifications, 0);
    });
  }

  _case('L11 disposed controller cannot attach and completed D stays success', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final d = h.track(h.sheet.whenDetached());
    h.sheet.dismiss();
    await tester.pumpAndSettle();
    _success(d);
    h.disposeController();
    final duplicate = _InstallOnlyRoute(h.nav.currentState!, h.sheet);
    expect(() => duplicate.install(), throwsStateError);
    duplicate.dispose();
    expect(d.error, isNull);
    expect(d.completions, 1);
  });

  _case('L10 disposing inside notification fails without clearing ownership', (
    tester,
    h,
  ) async {
    await h.present(tester);
    Object? failure;
    var attempted = false;
    h.sheet.addListener(() {
      if (attempted) return;
      attempted = true;
      try {
        h.sheet.dispose();
      } catch (error) {
        failure = error;
      }
    });
    final a = h.track(h.sheet.animateToDetent('large'));
    expect(failure, isA<AssertionError>());
    expect(h.sheet.isAttached, isTrue);
    expect(h.sheet.selectedDetentIdentifier, 'large');
    await tester.pumpAndSettle();
    expect(a.value, isTrue);
  });

  _case('L12 throwing onDismissed still settles waits and cleans tickers', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    final failure = StateError('expected dismissal callback failure');
    final route = _CapturingDismissedFailureRoute(h.sheet, failure);
    h.route = route;
    h.popped = _Probe(
      h.nav.currentState!.push<Object>(route),
      onDone: () => h.events.add('popped'),
    );
    await tester.pumpAndSettle();
    final d = h.track(h.sheet.whenDetached());
    final a = h.track(h.sheet.animateToDetent('large'));
    h.sheet.dismiss();
    await tester.pumpAndSettle();
    expect(route.failure, same(failure));
    _success(d);
    expect(a.value, isFalse);
    expect(h.sheet.isAttached, isFalse);
    h.push();
    await tester.pumpAndSettle();
    expect(h.sheet.isAttached, isTrue);
    expect(d.completions, 1);
  });

  _case('M01 accepted getters and callbacks precede async semantic success', (
    tester,
    h,
  ) async {
    await h.present(tester);
    h.sheet.addListener(() {
      if (h.sheet.restingDetentIdentifier == 'large') {
        h.events.add('rest-listener');
      }
    });
    final a = h.track(h.sheet.animateToDetent('large'), 'A');
    expect(h.sheet.selectedDetentIdentifier, 'large');
    expect(h.sheet.requestedDetentIdentifier, 'large');
    expect(h.sheet.targetDetentIdentifier, 'large');
    expect(h.sheet.restingDetentIdentifier, isNull);
    expect(h.events, contains('selected:large'));
    expect(a.done, isFalse);
    final p = h.track(h.sheet.whenPresented());
    await tester.idle();
    _success(p);
    expect(a.done, isFalse);
    await h.interior(tester);
    expect(a.done, isFalse);
    await tester.pumpAndSettle();
    expect(a.value, isTrue);
    expect(a.error, isNull);
    expect(h.sheet.restingDetentIdentifier, 'large');
    _before(h.events, 'selected:large', 'A');
    _before(h.events, 'rest-listener', 'A');
    expect(h.events.where((event) => event == 'selected:large'), hasLength(1));
  });

  _case('M02 already resting validates then succeeds with no ticker or frame', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final a = h.track(h.sheet.animateToDetent('short'));
    expect(a.done, isFalse);
    expect(h.isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.idle();
    expect(a.value, isTrue);
    expect(h.events, isEmpty);
    expect(h.sheet.restingDetentIdentifier, 'short');
    h.sheet.selectDetent('short');
    expect(h.isAnimating, isTrue);
    await tester.pumpAndSettle();
  });

  for (final ingress in [
    'animate',
    'select',
    'route',
    'same-animate',
    'same-select',
  ]) {
    _case('M03 $ingress supersedes without waiting for a status change', (
      tester,
      h,
    ) async {
      await h.present(tester);
      final first = h.track(h.sheet.animateToDetent('large'), 'old');
      final id = ingress.startsWith('same') ? 'large' : 'short';
      _Probe<bool>? next;
      switch (ingress) {
        case 'animate':
        case 'same-animate':
          next = h.track(h.sheet.animateToDetent(id));
        case 'route':
          h.route.selectDetent(id);
        default:
          h.sheet.selectDetent(id);
      }
      expect(first.done, isFalse);
      await tester.idle();
      expect(first.value, isFalse);
      await tester.pumpAndSettle();
      if (next != null) expect(next.value, isTrue);
      expect(first.value, isFalse);
      expect(first.completions, 1);
      expect(h.sheet.restingDetentIdentifier, id);
      if (ingress.startsWith('same')) {
        expect(
          h.events.where((event) => event == 'selected:large'),
          hasLength(1),
        );
      }
    });
  }

  _case('M03 A B A retains operation identity across an interior reversal', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final first = h.track(h.sheet.animateToDetent('large'));
    await h.interior(tester);
    final second = h.track(h.sheet.animateToDetent('short'));
    final third = h.track(h.sheet.animateToDetent('large'));
    await tester.idle();
    expect(first.value, isFalse);
    expect(second.value, isFalse);
    await tester.pumpAndSettle();
    expect(third.value, isTrue);
    expect(first.completions, 1);
    expect(second.completions, 1);
  });

  _case('M04 detached disposed and invalid identifiers fail synchronously', (
    tester,
    h,
  ) async {
    expect(() => h.sheet.animateToDetent('large'), throwsStateError);
    await h.present(tester);
    final a = h.track(h.sheet.animateToDetent('large'));
    expect(() => h.sheet.animateToDetent('missing'), throwsArgumentError);
    await tester.idle();
    expect(a.done, isFalse);
    await tester.pumpAndSettle();
    expect(a.value, isTrue);
    h.sheet.dismiss();
    expect(() => h.sheet.animateToDetent('large'), throwsStateError);
    await tester.pumpAndSettle();
    h.disposeController();
    expect(() => h.sheet.animateToDetent('large'), throwsStateError);
  });

  _case('M04 covered validation resolves unknown ID before availability', (
    tester,
    h,
  ) async {
    await h.present(tester);
    h.cover();
    await tester.pumpAndSettle();
    expect(() => h.sheet.animateToDetent('missing'), throwsArgumentError);
    expect(() => h.sheet.animateToDetent('large'), throwsStateError);
    expect(() => h.sheet.dismiss(), throwsStateError);
  });

  _case('M04 logically removed but attached route rejects new selections', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final d = h.track(h.sheet.whenDetached());
    h.sheet.dismiss();
    expect(h.sheet.isAttached, isTrue);
    expect(() => h.sheet.animateToDetent('large'), throwsStateError);
    expect(() => h.sheet.selectDetent('large'), throwsStateError);
    await tester.idle();
    expect(d.done, isFalse);
  });

  for (final invalid in _InvalidModel.values) {
    _case(
      'M05 rejected ${invalid.name} preserves IDs model and old operation',
      (tester, h) async {
        final model = _ControlledModel();
        await h.present(tester, model: model);
        final a = h.track(h.sheet.animateToDetent('large'));
        await h.interior(tester);
        final snapshot = h.sheet.snapshotState();
        model.invalid = invalid;
        expect(
          () => h.sheet.animateToDetent('short'),
          invalid == _InvalidModel.throwing
              ? throwsArgumentError
              : throwsStateError,
        );
        expect(h.sheet.selectedDetentIdentifier, 'large');
        expect(h.sheet.targetDetentIdentifier, 'large');
        expect(
          h.sheet.snapshotState().motionRequest,
          same(snapshot.motionRequest),
        );
        expect(
          h.sheet.snapshotState().motionTargetPoints,
          snapshot.motionTargetPoints,
        );
        expect(
          h.sheet.snapshotState().provenance['motion'],
          snapshot.provenance['motion'],
        );
        await tester.idle();
        expect(a.done, isFalse);
        model.invalid = null;
        await tester.pumpAndSettle();
        expect(a.value, isTrue);
      },
    );
  }

  _case('M02 same resting ID still constructs and validates the model', (
    tester,
    h,
  ) async {
    final model = _ControlledModel();
    await h.present(tester, model: model);
    final before = model.calls;
    model.invalid = _InvalidModel.target;
    expect(() => h.sheet.animateToDetent('short'), throwsStateError);
    expect(model.calls, before + 1);
    expect(h.sheet.restingDetentIdentifier, 'short');
    expect(h.isAnimating, isFalse);
  });

  for (final nested in ['selection', 'dismissal', 'disposal']) {
    _case('M06 model reentrant $nested invalidates outer without rollback', (
      tester,
      h,
    ) async {
      final model = _ControlledModel();
      await h.present(tester, model: model);
      _Probe<bool>? inner;
      model.onCreate = () {
        switch (nested) {
          case 'selection':
            inner = h.track(h.sheet.animateToDetent('short'));
          case 'dismissal':
            h.sheet.dismiss();
          case 'disposal':
            h.disposeController();
        }
      };
      expect(() => h.sheet.animateToDetent('large'), throwsStateError);
      expect(h.events, isNot(contains('selected:large')));
      await tester.pumpAndSettle();
      if (inner != null) {
        expect(inner!.value, isTrue);
        expect(h.sheet.restingDetentIdentifier, 'short');
      } else {
        expect(h.sheet.isAttached, isFalse);
      }
    });
  }

  _case('M06 selected callback retarget wins over outer notification', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    _Probe<bool>? inner;
    h.push(
      onSelected: (id) {
        if (id == 'large') inner = h.track(h.sheet.animateToDetent('short'));
      },
    );
    await tester.pumpAndSettle();
    final outer = h.track(h.sheet.animateToDetent('large'));
    expect(h.sheet.selectedDetentIdentifier, 'short');
    await tester.pumpAndSettle();
    expect(outer.value, isFalse);
    expect(inner!.value, isTrue);
    expect(h.sheet.restingDetentIdentifier, 'short');
  });

  _case(
    'M06 throwing selected callback retains accepted motion until terminal',
    (tester, h) async {
      await h.mount(tester);
      final failure = ArgumentError('expected selection callback failure');
      h.push(
        onSelected: (id) {
          if (id == 'large') throw failure;
        },
      );
      await tester.pumpAndSettle();
      expect(() => h.sheet.animateToDetent('large'), throwsA(same(failure)));
      expect(h.sheet.selectedDetentIdentifier, 'large');
      await tester.pumpAndSettle();
      expect(h.sheet.restingDetentIdentifier, 'large');
      final d = h.track(h.sheet.whenDetached());
      h.sheet.dismiss();
      await tester.pumpAndSettle();
      _success(d);
    },
  );

  _case('M06 onPresented dismiss preserves P and cancels pending A', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    h.push(
      onPresented: () {
        expect(h.sheet.isPresented, isTrue);
        h.sheet.dismiss();
      },
    );
    final p = h.track(h.sheet.whenPresented());
    final d = h.track(h.sheet.whenDetached());
    final a = h.track(h.sheet.animateToDetent('large'));
    await tester.pumpAndSettle();
    _success(p);
    _success(d);
    expect(a.value, isFalse);
  });

  _case('M07 sheet drag start cancels before any drag value delta', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final a = h.track(h.sheet.animateToDetent('large'));
    await h.interior(tester);
    final before = h.sheet.unscaledTrajectoryHeight;
    final detector = tester.widget<GestureDetector>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is GestureDetector && widget.onVerticalDragStart != null,
          )
          .last,
    );
    // Invoke the real mounted recognizer's production start callback alone.
    // This deterministic boundary test is paired with real pointer tests below.
    detector.onVerticalDragStart!(DragStartDetails());
    expect(h.route.isUserDragging, isTrue);
    expect(h.sheet.unscaledTrajectoryHeight, before);
    expect(a.done, isFalse);
    await tester.idle();
    expect(a.value, isFalse);
    detector.onVerticalDragEnd!(DragEndDetails(primaryVelocity: 0));
    await tester.pumpAndSettle();
    expect(a.value, isFalse);
    expect(h.route.isUserDragging, isFalse);
  });

  for (final finish in ['release', 'cancel', 'teardown']) {
    _case('M07 real pointer ownership and $finish cannot revive a request', (
      tester,
      h,
    ) async {
      // Keep the arena contested on pointer-down so ownership begins only after
      // the vertical move proves this is a sheet drag.
      await h.present(
        tester,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: const Center(child: Text('Sheet content')),
        ),
      );
      final a = h.track(h.sheet.animateToDetent('large'));
      await h.interior(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Sheet content')),
      );
      await tester.idle();
      expect(h.route.isUserDragging, isFalse);
      expect(a.done, isFalse);
      await gesture.moveBy(const Offset(0, -60));
      await tester.idle();
      expect(h.route.isUserDragging, isTrue);
      expect(a.value, isFalse);
      switch (finish) {
        case 'release':
          await gesture.up();
        case 'cancel':
          await gesture.cancel();
        case 'teardown':
          await tester.pumpWidget(const SizedBox.shrink());
          await gesture.cancel();
      }
      await tester.pumpAndSettle();
      expect(h.route.isUserDragging, isFalse);
      expect(a.value, isFalse);
      expect(a.completions, 1);
      if (finish == 'cancel') expect(h.sheet.isAttached, isTrue);
    });
  }

  _case('M07 scroll only gesture does not acquire sheet ownership', (
    tester,
    h,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await h.present(
      tester,
      interaction: IosSheetContentInteraction.scrolls,
      child: ListView.builder(
        controller: scroll,
        itemExtent: 50,
        itemCount: 100,
        itemBuilder: (_, index) => Text('Row $index'),
      ),
    );
    final a = h.track(h.sheet.animateToDetent('large'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    // The first event crosses touch slop; the second produces scroll movement.
    await gesture.moveBy(const Offset(0, -40));
    await gesture.moveBy(const Offset(0, -80));
    await tester.idle();
    expect(scroll.offset, greaterThan(0));
    expect(h.route.isUserDragging, isFalse);
    expect(a.done, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(a.value, isTrue);
  });

  _case('M09 command during owned drag accepts selection but returns false', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Sheet content')),
    );
    await gesture.moveBy(const Offset(0, -60));
    expect(h.route.isUserDragging, isTrue);
    final a = h.track(h.sheet.animateToDetent('large'));
    expect(h.sheet.selectedDetentIdentifier, 'large');
    expect(h.events, contains('selected:large'));
    await tester.idle();
    expect(a.value, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(a.value, isFalse);
    expect(a.completions, 1);
  });

  _case('M08 owner disposal during real drag leaves live route independent', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final d = h.track(h.sheet.whenDetached());
    final a = h.track(h.sheet.animateToDetent('large'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Sheet content')),
    );
    await gesture.moveBy(const Offset(0, -60));
    expect(h.route.isUserDragging, isTrue);
    var notifications = 0;
    h.sheet.addListener(() => notifications++);
    h.disposeController();
    await tester.idle();
    expect(d.error, isA<StateError>());
    expect(a.value, isFalse);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(h.route.isUserDragging, isFalse);
    expect(h.route.isActive, isTrue);
    expect(notifications, 0);
    h.nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(notifications, 0);
  });

  for (final dismissal in ['controller', 'navigator', 'barrier', 'gesture']) {
    _case('M10 $dismissal cancellation precedes actual route detachment', (
      tester,
      h,
    ) async {
      await h.present(tester);
      final a = h.track(h.sheet.animateToDetent('large'));
      final d = h.track(h.sheet.whenDetached());
      // A barrier point remains uncovered before the first motion tick.
      switch (dismissal) {
        case 'controller':
          h.sheet.dismiss();
        case 'navigator':
          h.nav.currentState!.pop();
        case 'barrier':
          await tester.tapAt(const Offset(200, 20));
        case 'gesture':
          await tester.timedDrag(
            find.text('Sheet content'),
            const Offset(0, 650),
            const Duration(milliseconds: 120),
          );
      }
      await tester.idle();
      expect(a.value, isFalse);
      expect(h.sheet.isAttached, isTrue);
      expect(d.done, isFalse);
      await tester.pumpAndSettle();
      _success(d);
      expect(a.completions, 1);
    });
  }

  _case('M10 rejected maybePop leaves presentation and detachment live', (
    tester,
    h,
  ) async {
    await h.mount(tester);
    h.push(
      fixedOpening: true,
      child: PopScope<Object>(
        canPop: false,
        child: const Text('Sheet content'),
      ),
    );
    final p = h.track(h.sheet.whenPresented());
    final d = h.track(h.sheet.whenDetached());
    await tester.pump();
    final handled = await h.nav.currentState!.maybePop();
    expect(handled, isTrue);
    await tester.idle();
    expect(p.done || d.done, isFalse);
    await tester.pumpAndSettle();
    _success(p);
    expect(h.sheet.isAttached, isTrue);
    expect(d.done, isFalse);
  });

  for (final secondSheet in [false, true]) {
    _case('M11 ${secondSheet ? 'sheet' : 'page'} cover cancels after idle', (
      tester,
      h,
    ) async {
      await h.present(tester);
      final a = h.track(h.sheet.animateToDetent('large'));
      final d = h.track(h.sheet.whenDetached());
      await h.interior(tester);
      if (secondSheet) {
        h.nav.currentState!.push(
          StupidSimpleIosSheetRoute<void>(
            profile: IosSheetProfile.ios26,
            child: const Text('Cover'),
          ),
        );
      } else {
        h.cover();
      }
      await tester.idle();
      expect(h.route.isCurrent, isFalse);
      expect(a.value, isFalse);
      expect(d.done, isFalse);
      await tester.pumpAndSettle();
      h.nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(a.value, isFalse);
      expect(h.sheet.isAttached, isTrue);
      final fresh = h.track(h.sheet.animateToDetent('short'));
      await tester.pumpAndSettle();
      expect(fresh.value, isTrue);
    });
  }

  for (final removal in _Removal.values) {
    for (final beforeTick in [false, true]) {
      _case(
        'M12 ${removal.name} ${beforeTick ? 'before tick' : 'mid snap'} settles all waits',
        (tester, h) async {
          await h.present(tester);
          final a = h.track(h.sheet.animateToDetent('large'));
          final d = h.track(h.sheet.whenDetached());
          if (!beforeTick) await h.interior(tester);
          await h.remove(tester, removal);
          expect(a.value, isFalse);
          _success(d);
          expect(h.sheet.isAttached, isFalse);
          expect(a.completions, 1);
        },
      );
    }
  }

  _case('M12 covered removal terminates motion without waiting for ticker', (
    tester,
    h,
  ) async {
    await h.present(tester);
    final a = h.track(h.sheet.animateToDetent('large'));
    final d = h.track(h.sheet.whenDetached());
    h.cover();
    await tester.idle();
    expect(a.value, isFalse);
    h.nav.currentState!.removeRoute(h.route);
    await tester.pumpAndSettle();
    _success(d);
    expect(a.value, isFalse);
  });

  _case('M13 equal height semantic alias and old generation stay distinct', (
    tester,
    h,
  ) async {
    await h.present(
      tester,
      detents: [
        IosSheetDetent.height('short', 300),
        IosSheetDetent.height('alias', 300),
        IosSheetDetent.large,
      ],
    );
    final alias = h.track(h.sheet.animateToDetent('alias'));
    await tester.pumpAndSettle();
    expect(alias.value, isTrue);
    expect(h.sheet.restingDetentIdentifier, 'alias');
    final old = h.track(h.sheet.animateToDetent('large'));
    final d = h.track(h.sheet.whenDetached());
    h.sheet.dismiss();
    await tester.pumpAndSettle();
    expect(old.value, isFalse);
    _success(d);
    h.push();
    await tester.pumpAndSettle();
    final fresh = h.track(h.sheet.animateToDetent('large'));
    await tester.pumpAndSettle();
    expect(fresh.value, isTrue);
    expect(old.value, isFalse);
    expect(old.completions, 1);
    expect(h.sheet.restingDetentIdentifier, 'large');
  });

  for (final interruption in ['retarget', 'stop', 'matching-value']) {
    _case('M14 low level $interruption cancels captured ticker ownership', (
      tester,
      h,
    ) async {
      await h.present(tester);
      final a = h.track(h.sheet.animateToDetent('large'));
      await h.interior(tester);
      // ignore: invalid_use_of_protected_member
      final engine = h.route.controller!;
      switch (interruption) {
        case 'retarget':
          h.route.animateToRelative(300 / 800, snap: true);
        case 'stop':
          engine.stop();
        case 'matching-value':
          engine.value = 1;
      }
      await tester.idle();
      expect(a.value, isFalse);
      await tester.pumpAndSettle();
      expect(a.value, isFalse);
      expect(a.completions, 1);
    });
  }

  _case('M14 fulfilled ticker at wrong semantic rest resolves false', (
    tester,
    h,
  ) async {
    final model = _ControlledModel();
    await h.present(tester, model: model);
    model.wrongEnd = true;
    final a = h.track(h.sheet.animateToDetent('large'));
    await tester.pumpAndSettle();
    expect(h.isAnimating, isFalse);
    expect(h.sheet.restingDetentIdentifier, isNull);
    expect(a.done, isTrue);
    expect(a.value, isFalse);
    expect(a.error, isNull);
  });

  for (final terminal in ['select', 'animate', 'dismiss']) {
    _case('M15 final tick listener $terminal wins before ticker success', (
      tester,
      h,
    ) async {
      await h.present(tester);
      var fired = false;
      _Probe<bool>? replacement;
      h.sheet.addListener(() {
        if (fired || h.sheet.restingDetentIdentifier != 'large') return;
        fired = true;
        switch (terminal) {
          case 'select':
            h.sheet.selectDetent('short');
          case 'animate':
            replacement = h.track(h.sheet.animateToDetent('short'));
          case 'dismiss':
            h.sheet.dismiss();
        }
      });
      final a = h.track(h.sheet.animateToDetent('large'));
      await tester.pumpAndSettle();
      expect(fired, isTrue);
      expect(a.value, isFalse);
      expect(a.completions, 1);
      if (replacement != null) expect(replacement!.value, isTrue);
      if (terminal != 'dismiss')
        expect(h.sheet.restingDetentIdentifier, 'short');
    });
  }
}

enum _Removal { remove, replace, teardown }

// The framework normally assigns Navigator before install. This fixture
// provides that same context without inserting a deliberately invalid route
// into Navigator history; all installation/attachment code remains real.
class _InstallOnlyRoute extends StupidSimpleIosSheetRoute<Object> {
  _InstallOnlyRoute(this.owner, IosSheetController sheet)
    : super(
        profile: IosSheetProfile.ios26,
        controller: sheet,
        child: const SizedBox.shrink(),
      );

  final NavigatorState owner;

  @override
  NavigatorState get navigator => owner;
}

// Navigator disposes routes in a microtask. Capture the callback failure at the
// public route boundary so the test can assert it without failing the test zone.
class _CapturingDismissedFailureRoute
    extends StupidSimpleIosSheetRoute<Object> {
  _CapturingDismissedFailureRoute(
    IosSheetController sheet,
    this.expectedFailure,
  ) : super(
        profile: IosSheetProfile.ios26,
        controller: sheet,
        detents: [IosSheetDetent.height('short', 300), IosSheetDetent.large],
        initialDetentIdentifier: 'short',
        onDismissed: () => throw expectedFailure,
        child: const ColoredBox(
          color: Colors.white,
          child: Center(child: Text('Sheet content')),
        ),
      );

  final Object expectedFailure;
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

typedef _Body = Future<void> Function(WidgetTester tester, _Harness harness);

void _case(String name, _Body body) {
  testWidgets(name, (tester) async {
    final h = _Harness();
    try {
      await body(tester, h);
    } finally {
      await h.clean(tester);
    }
  });
}

void _success(_Probe<void> probe) {
  expect(probe.done, isTrue);
  expect(probe.error, isNull);
  expect(probe.completions, 1);
}

void _before(List<String> events, String first, String second) {
  expect(events, contains(first));
  expect(events, contains(second));
  expect(events.indexOf(first), lessThan(events.indexOf(second)));
}

class _Probe<T> {
  _Probe(this.future, {VoidCallback? onDone}) {
    future.then<void>(
      (result) {
        done = true;
        completions++;
        value = result;
        onDone?.call();
      },
      onError: (Object failure, StackTrace stack) {
        done = true;
        completions++;
        error = failure;
        onDone?.call();
      },
    );
  }

  final Future<T> future;
  bool done = false;
  int completions = 0;
  T? value;
  Object? error;
}

class _Harness {
  final nav = GlobalKey<NavigatorState>();
  final sheet = IosSheetController();
  final events = <String>[];
  final pending = <bool Function()>[];
  bool ownerDisposed = false;
  late StupidSimpleIosSheetRoute<Object> route;
  late _Probe<Object?> popped;

  // ignore: invalid_use_of_protected_member
  bool get isAnimating => route.controller!.isAnimating;

  _Probe<T> track<T>(Future<T> future, [String? label, VoidCallback? onDone]) {
    final probe = _Probe<T>(
      future,
      onDone: () {
        if (label != null) events.add(label);
        onDone?.call();
      },
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
    ValueChanged<String>? onSelected,
    IosSheetTrajectoryModel? model,
    IosSheetContentInteraction interaction = IosSheetContentInteraction.resizes,
    List<IosSheetDetent>? detents,
    Widget? child,
  }) {
    route = StupidSimpleIosSheetRoute<Object>(
      profile: IosSheetProfile.ios26.copyWith(
        fixedSurfaceDuringTransition: fixedOpening,
      ),
      controller: sheet,
      detents:
          detents ??
          [IosSheetDetent.height('short', 300), IosSheetDetent.large],
      initialDetentIdentifier: 'short',
      trajectoryModel: model,
      contentInteraction: interaction,
      onPresented: () {
        events.add('onPresented');
        onPresented?.call();
      },
      onDismissed: () {
        events.add('onDismissed');
        onDismissed?.call();
      },
      onSelectedDetentChanged: (id) {
        events.add('selected:$id');
        onSelected?.call(id);
      },
      child:
          child ??
          const ColoredBox(
            color: Colors.white,
            child: Center(child: Text('Sheet content')),
          ),
    );
    // Route.popped has no Navigator-teardown guarantee, so it is deliberately
    // outside the API-future registry. Tests for pop/remove/replace assert it.
    popped = _Probe(
      nav.currentState!.push<Object>(route),
      onDone: () => events.add('popped'),
    );
  }

  Future<void> present(
    WidgetTester tester, {
    IosSheetTrajectoryModel? model,
    IosSheetContentInteraction interaction = IosSheetContentInteraction.resizes,
    List<IosSheetDetent>? detents,
    Widget? child,
  }) async {
    await mount(tester);
    push(
      model: model,
      interaction: interaction,
      detents: detents,
      child: child,
    );
    await tester.pumpAndSettle();
    expect(sheet.restingDetentIdentifier, 'short');
    events.clear();
  }

  void cover({bool opaque = true}) {
    nav.currentState!.push<void>(
      PageRouteBuilder<void>(
        opaque: opaque,
        pageBuilder: (_, animation, secondaryAnimation) => const Text('Cover'),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> interior(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> remove(WidgetTester tester, _Removal removal) async {
    switch (removal) {
      case _Removal.remove:
        nav.currentState!.removeRoute(route);
      case _Removal.replace:
        nav.currentState!.pushReplacement<void, Object>(
          MaterialPageRoute<void>(builder: (_) => const Text('Replacement')),
        );
      case _Removal.teardown:
        await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.pumpAndSettle();
    await tester.idle();
  }

  void disposeController() {
    sheet.dispose();
    ownerDisposed = true;
  }

  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.idle();
    expect(sheet.isAttached, isFalse);
    expect(
      pending.every((isDone) => isDone()),
      isTrue,
      reason: 'Every tracked lifecycle API future must terminate after unmount',
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    if (!ownerDisposed) disposeController();
  }
}

enum _InvalidModel { throwing, target, position, velocity, nonfiniteVelocity }

class _ControlledModel implements IosSheetTrajectoryModel {
  _InvalidModel? invalid;
  bool wrongEnd = false;
  VoidCallback? onCreate;
  int calls = 0;

  @override
  IosSheetTrajectory createTrajectory(IosSheetMotionRequest request) {
    calls++;
    final callback = onCreate;
    onCreate = null;
    callback?.call();
    if (invalid == _InvalidModel.throwing)
      throw ArgumentError('synthetic model failure');
    final base = const FallbackIosSheetTrajectoryModel(
      CupertinoMotion.smooth(snapToEnd: true),
    ).createTrajectory(request);
    return IosSheetTrajectory(
      simulation: _ControlledSimulation(base.simulation, invalid, wrongEnd),
      targetPoints:
          request.targetPoints + (invalid == _InvalidModel.target ? 1 : 0),
      provenance: 'synthetic acceptance model, not native evidence',
      capability: IosSheetCapabilityStatus.fallback,
    );
  }
}

class _ControlledSimulation extends Simulation {
  _ControlledSimulation(this.inner, this.invalid, this.wrongEnd);
  final Simulation inner;
  final _InvalidModel? invalid;
  final bool wrongEnd;

  @override
  double x(double time) =>
      inner.x(time) +
      (invalid == _InvalidModel.position || (wrongEnd && inner.isDone(time))
          ? 1
          : 0);

  @override
  double dx(double time) {
    if (time == 0 && invalid == _InvalidModel.velocity) return 0;
    if (time == 0 && invalid == _InvalidModel.nonfiniteVelocity)
      return double.nan;
    return inner.dx(time);
  }

  @override
  bool isDone(double time) => inner.isDone(time);
}
