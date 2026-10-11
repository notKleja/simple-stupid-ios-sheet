import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_sheet_engine/ios_sheet_engine.dart'
    show SheetSnappingConfig;
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

class _LifecycleModel implements IosSheetTrajectoryModel {
  bool failure = false;
  String? invalid;
  VoidCallback? onCreate;
  VoidCallback? onStartup;
  @override
  IosSheetTrajectory createTrajectory(IosSheetMotionRequest request) {
    onCreate?.call();
    if (failure) throw StateError('expected model failure');
    final trajectory = FallbackIosSheetTrajectoryModel(
      const CupertinoMotion.smooth(snapToEnd: true),
    ).createTrajectory(request);
    if (onStartup == null && invalid == null) return trajectory;
    return IosSheetTrajectory(
      simulation: _StartupSimulation(trajectory.simulation, this),
      targetPoints: trajectory.targetPoints + (invalid == 'target' ? 1 : 0),
      provenance: trajectory.provenance,
      capability: trajectory.capability,
    );
  }
}

class _StartupSimulation extends Simulation {
  _StartupSimulation(this.inner, this.model);
  final Simulation inner;
  final _LifecycleModel model;
  int samples = 0;
  @override
  double x(double time) {
    if (++samples == 2) model.onStartup?.call();
    return inner.x(time) +
        (model.invalid == 'position' || (model.invalid == 'rest' && time > 0)
            ? 1
            : 0);
  }

  @override
  double dx(double time) =>
      model.invalid == 'velocity' ? double.nan : inner.dx(time);
  @override
  bool isDone(double time) => inner.isDone(time);
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
    ValueChanged<String>? onSelected,
    IosSheetTrajectoryModel? model,
    List<IosSheetDetent>? detents,
    bool tapCompetition = false,
  }) {
    route = StupidSimpleIosSheetRoute<Object>(
      profile: IosSheetProfile.ios26.copyWith(
        fixedSurfaceDuringTransition: fixedOpening,
      ),
      controller: sheet,
      detents:
          detents ??
          [IosSheetDetent.height('short', 300), IosSheetDetent.large],
      trajectoryModel: model,
      onSelectedDetentChanged: (identifier) {
        events.add('selected:$identifier');
        onSelected?.call(identifier);
      },
      initialDetentIdentifier: 'short',
      onPresented: () {
        events.add('onPresented');
        onPresented?.call();
      },
      onDismissed: () {
        events.add('onDismissed');
        onDismissed?.call();
      },
      child: ColoredBox(
        color: Colors.white,
        child: Center(
          child: tapCompetition
              ? GestureDetector(
                  onTap: () {},
                  child: const Text('Sheet content'),
                )
              : const Text('Sheet content'),
        ),
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
  for (final ingress in ['model', 'startup']) {
    for (final semantic in [false, true]) {
      testWidgets(
        'M06 alias $ingress retarget preserves ${semantic ? 'new semantic owner' : 'prior semantic target'}',
        (tester) async {
          final h = _Harness();
          final model = _LifecycleModel();
          await h.mount(tester);
          h.push(
            model: model,
            detents: [
              IosSheetDetent.height('short', 300),
              IosSheetDetent.height('alias', 300),
              IosSheetDetent.large,
            ],
          );
          await tester.pumpAndSettle();
          h.events.clear();
          _Probe<bool>? newer;
          late _Probe<void> physical;
          void retarget() {
            model.onCreate = null;
            model.onStartup = null;
            if (semantic) newer = h.track(h.sheet.animateToDetent('alias'));
            physical = h.track(h.route.animateToRelative(.375).orCancel);
          }

          if (ingress == 'model') {
            model.onCreate = retarget;
          } else {
            model.onStartup = retarget;
          }
          Object? failure;
          try {
            h.sheet.animateToDetent('alias').ignore();
          } catch (error) {
            failure = error;
          }
          expect(failure, isA<StateError>());
          final observedTarget = h.sheet.targetDetentIdentifier;
          final identifier = semantic ? 'alias' : 'short';
          expect(h.sheet.selectedDetentIdentifier, identifier);
          expect(h.route.targetRelativePosition, .375);
          expect(h.sheet.snapshotState().motionTargetPoints, 300);
          await tester.pumpAndSettle();
          expect(observedTarget, identifier);
          expect(h.sheet.targetDetentIdentifier, identifier);
          expect(h.sheet.restingDetentIdentifier, identifier);
          expect(h.sheet.selectedDetentIdentifier, identifier);
          if (!semantic) expect(h.events, isNot(contains('selected:alias')));
          expect(physical.done, isTrue);
          expect(physical.error, isNull);
          if (newer != null) expect(newer!.value, isTrue);
          await h.clean(tester);
        },
      );
    }
  }

  testWidgets(
    'M06 nested semantic acceptance survives later nonsemantic engine retarget',
    (tester) async {
      final h = _Harness();
      final model = _LifecycleModel();
      await h.mount(tester);
      h.push(model: model);
      await tester.pumpAndSettle();
      h.events.clear();
      late _Probe<bool> semantic;
      late _Probe<void> physical;
      model.onCreate = () {
        model.onCreate = null;
        semantic = h.track(h.sheet.animateToDetent('large'));
        physical = h.track(h.route.animateToRelative(.5).orCancel);
      };
      Object? failure;
      try {
        h.sheet.animateToDetent('large').ignore();
      } catch (error) {
        failure = error;
      }
      expect(failure, isA<StateError>());
      expect(h.sheet.selectedDetentIdentifier, 'large');
      expect(h.events.where((event) => event == 'selected:large'), isEmpty);
      expect(h.sheet.snapshotState().motionTargetPoints, 400);
      await tester.pumpAndSettle();
      expect(semantic.value, isFalse);
      expect(physical.done, isTrue);
      expect(physical.error, isNull);
      expect(h.sheet.unscaledTrajectoryHeight, closeTo(400, 1e-6));
      await h.clean(tester);
    },
  );

  testWidgets(
    'M06 already compliant nested config preserves outer semantic command',
    (tester) async {
      final h = _Harness();
      final model = _LifecycleModel();
      await h.mount(tester);
      h.push(model: model);
      await tester.pumpAndSettle();
      model.onCreate = () {
        model.onCreate = null;
        h.route
            .overrideSnappingConfig(
              const SheetSnappingConfig([.375]),
              animateToComply: true,
            )
            .orCancel
            .ignore();
      };
      final outer = h.track(h.sheet.animateToDetent('large'));
      await tester.pumpAndSettle();
      expect(outer.value, isTrue);
      expect(h.sheet.selectedDetentIdentifier, 'large');
      await h.clean(tester);
    },
  );

  for (final ingress in ['model', 'startup', 'config']) {
    for (final target in [.5, .375, 1.0]) {
      if (ingress == 'config' && target != .5) continue;
      testWidgets(
        'M06 nested engine $ingress retarget to $target rejects outer transaction',
        (tester) async {
          final h = _Harness();
          final model = _LifecycleModel();
          await h.mount(tester);
          h.push(model: model);
          await tester.pumpAndSettle();
          h.events.clear();
          late _Probe<void> nested;
          void retarget() {
            model.onCreate = null;
            model.onStartup = null;
            if (ingress == 'config') {
              nested = h.track(
                h.route
                    .overrideSnappingConfig(
                      SheetSnappingConfig([target]),
                      animateToComply: true,
                    )
                    .orCancel,
              );
            } else {
              nested = h.track(h.route.animateToRelative(target).orCancel);
            }
          }

          if (ingress != 'startup') {
            model.onCreate = retarget;
          } else {
            model.onStartup = retarget;
          }
          Object? failure;
          try {
            h.sheet.animateToDetent('large').ignore();
          } catch (error) {
            failure = error;
          }
          expect(failure, isA<StateError>());
          expect(h.route.targetRelativePosition, target);
          expect(h.sheet.snapshotState().motionTargetPoints, target * 800);
          expect(h.events, isNot(contains('selected:large')));
          expect(h.sheet.selectedDetentIdentifier, 'short');
          await tester.pumpAndSettle();
          expect(nested.done, isTrue);
          expect(nested.error, isNull);
          expect(h.sheet.unscaledTrajectoryHeight, closeTo(target * 800, 1e-6));
          expect(h.sheet.targetDetentIdentifier, switch (target) {
            .375 => 'short',
            1.0 => 'large',
            _ => isNull,
          });
          await h.clean(tester);
        },
      );
    }
  }

  for (final finish in ['release', 'cancel', 'teardown']) {
    testWidgets(
      'M07 eager pointer ownership and $finish preserves cancellation',
      (tester) async {
        final h = _Harness();
        await h.present(tester);
        final a = h.track(h.sheet.animateToDetent('large'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(a.done, isFalse);
        final height = h.sheet.unscaledTrajectoryHeight;
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Sheet content')),
        );
        await tester.idle();
        expect(h.route.isUserDragging, isTrue);
        expect(h.sheet.unscaledTrajectoryHeight, height);
        expect(a.value, isFalse);
        await gesture.moveBy(const Offset(0, -60));
        await tester.idle();
        expect(h.route.isUserDragging, isTrue);
        expect(a.value, isFalse);
        if (finish == 'release') {
          await gesture.up();
        } else if (finish == 'cancel') {
          await gesture.cancel();
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
          await gesture.cancel();
        }
        await tester.pumpAndSettle();
        expect(a.value, isFalse);
        expect(h.route.isUserDragging, isFalse);
        await h.clean(tester);
      },
    );
  }

  testWidgets(
    'M07 opening drag teardown fails presentation without inactive context lookup',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push();
      final p = h.track(h.sheet.whenPresented());
      final d = h.track(h.sheet.whenDetached());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(p.done, isFalse);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Sheet content')),
      );
      await gesture.moveBy(const Offset(0, -30));
      expect(h.route.isUserDragging, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await gesture.cancel();
      await tester.idle();
      expect(p.error, isA<StateError>());
      expect(d.done, isTrue);
      expect(h.events, isNot(contains('onPresented')));
      await h.clean(tester);
    },
  );

  testWidgets(
    'M01 accepted selection is synchronous and succeeds after rest callbacks',
    (tester) async {
      final h = _Harness();
      await h.present(tester);
      h.sheet.addListener(() {
        if (h.sheet.restingDetentIdentifier == 'large') h.events.add('rest');
      });
      final a = h.track(h.sheet.animateToDetent('large'), 'A');
      expect(h.sheet.selectedDetentIdentifier, 'large');
      expect(h.events, contains('selected:large'));
      expect(a.done, isFalse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.done, isFalse);
      await tester.pumpAndSettle();
      expect(a.value, isTrue);
      expect(h.sheet.restingDetentIdentifier, 'large');
      expect(h.events.indexOf('rest'), lessThan(h.events.indexOf('A')));
      await h.clean(tester);
    },
  );

  testWidgets(
    'M02 already resting validates the model and succeeds asynchronously without a ticker',
    (tester) async {
      final h = _Harness();
      final model = _LifecycleModel();
      await h.mount(tester);
      h.push(model: model);
      await tester.pumpAndSettle();
      final a = h.track(h.sheet.animateToDetent('short'));
      expect(a.done, isFalse);
      // ignore: invalid_use_of_protected_member
      expect(h.route.controller!.isAnimating, isFalse);
      await tester.idle();
      expect(a.value, isTrue);
      model.failure = true;
      expect(() => h.sheet.animateToDetent('short'), throwsStateError);
      model.failure = false;
      h.sheet.selectDetent('short');
      // ignore: invalid_use_of_protected_member
      expect(h.route.controller!.isAnimating, isTrue);
      await h.clean(tester);
    },
  );

  for (final replacement in ['animate', 'legacy', 'route', 'same', 'ABA']) {
    testWidgets('M03 $replacement supersedes each accepted request', (
      tester,
    ) async {
      final h = _Harness();
      await h.present(tester);
      final first = h.track(h.sheet.animateToDetent('large'));
      _Probe<bool>? last;
      if (replacement == 'legacy') {
        h.sheet.selectDetent('short');
      } else if (replacement == 'route') {
        h.route.selectDetent('short');
      } else {
        last = h.track(
          h.sheet.animateToDetent(replacement == 'same' ? 'large' : 'short'),
        );
        if (replacement == 'ABA') {
          final middle = last;
          last = h.track(h.sheet.animateToDetent('large'));
          await tester.idle();
          expect(middle.value, isFalse);
        }
      }
      await tester.idle();
      expect(first.value, isFalse);
      await tester.pumpAndSettle();
      if (last != null) expect(last.value, isTrue);
      expect(first.value, isFalse);
      await h.clean(tester);
    });
  }

  testWidgets(
    'M04 rejected identifiers and M05 construction failures preserve prior motion and observations',
    (tester) async {
      final h = _Harness();
      final model = _LifecycleModel();
      await h.mount(tester);
      expect(() => h.sheet.animateToDetent('large'), throwsStateError);
      h.push(model: model);
      await tester.pumpAndSettle();
      final a = h.track(h.sheet.animateToDetent('large'));
      final request = h.sheet.snapshotState().motionRequest;
      expect(() => h.sheet.animateToDetent('missing'), throwsArgumentError);
      model.failure = true;
      expect(() => h.sheet.animateToDetent('short'), throwsStateError);
      model.failure = false;
      expect(h.sheet.selectedDetentIdentifier, 'large');
      expect(h.sheet.snapshotState().motionRequest, same(request));
      await tester.idle();
      expect(a.done, isFalse);
      await tester.pumpAndSettle();
      expect(a.value, isTrue);
      await h.clean(tester);
      expect(() => h.sheet.animateToDetent('short'), throwsStateError);
    },
  );

  for (final nested in ['model', 'selected', 'startup']) {
    testWidgets(
      'M06 reentrant $nested selection fences the outer transaction',
      (tester) async {
        final h = _Harness();
        final model = _LifecycleModel();
        late _Probe<bool> inner;
        await h.mount(tester);
        h.push(
          model: model,
          onSelected: (id) {
            if (nested == 'selected' && id == 'large')
              inner = h.track(h.sheet.animateToDetent('short'));
          },
        );
        await tester.pumpAndSettle();
        if (nested == 'model') {
          model.onCreate = () {
            model.onCreate = null;
            inner = h.track(h.sheet.animateToDetent('short'));
          };
        } else if (nested == 'startup') {
          model.onStartup = () {
            model.onStartup = null;
            inner = h.track(h.sheet.animateToDetent('short'));
          };
        }
        if (nested == 'selected') {
          final outer = h.track(h.sheet.animateToDetent('large'));
          await tester.idle();
          expect(outer.value, isFalse);
        } else {
          expect(() => h.sheet.animateToDetent('large'), throwsStateError);
        }
        expect(h.sheet.selectedDetentIdentifier, 'short');
        await tester.pumpAndSettle();
        expect(inner.value, isTrue);
        await h.clean(tester);
      },
    );
  }

  testWidgets(
    'M07 drag start before delta cancels while pointer down alone preserves ownership',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(tapCompetition: true);
      await tester.pumpAndSettle();
      final a = h.track(h.sheet.animateToDetent('large'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Sheet content')),
      );
      await tester.idle();
      expect(a.done, isFalse);
      await gesture.moveBy(const Offset(0, 30));
      expect(h.route.isUserDragging, isTrue);
      await tester.idle();
      expect(a.value, isFalse);
      final during = h.track(h.sheet.animateToDetent('short'));
      expect(h.sheet.selectedDetentIdentifier, 'short');
      await tester.idle();
      expect(during.value, isFalse);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(h.route.isUserDragging, isFalse);
      expect(a.value, isFalse);
      await h.clean(tester);
    },
  );

  for (final terminal in [
    'cover',
    'dismiss',
    'remove',
    'replace',
    'dispose',
    'unmount',
  ]) {
    testWidgets('M08-M12 $terminal promptly terminates owned selection', (
      tester,
    ) async {
      final h = _Harness();
      await h.present(tester);
      final a = h.track(h.sheet.animateToDetent('large'));
      final d = h.track(h.sheet.whenDetached());
      if (terminal == 'cover') {
        h.nav.currentState!
            .push<void>(
              MaterialPageRoute<void>(builder: (_) => const Text('Cover')),
            )
            .ignore();
      } else if (terminal == 'dismiss') {
        h.sheet.dismiss();
      } else if (terminal == 'remove') {
        h.nav.currentState!.removeRoute(h.route);
      } else if (terminal == 'replace') {
        h.nav.currentState!
            .pushReplacement<void, Object>(
              MaterialPageRoute<void>(
                builder: (_) => const Text('Replacement'),
              ),
            )
            .ignore();
      } else if (terminal == 'dispose') {
        h.disposeController();
      } else {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.idle();
      expect(a.value, isFalse);
      if (terminal == 'cover' || terminal == 'dismiss') expect(d.done, isFalse);
      await tester.pumpAndSettle();
      if (terminal == 'cover') {
        expect(() => h.sheet.animateToDetent('missing'), throwsArgumentError);
        expect(() => h.sheet.animateToDetent('short'), throwsStateError);
        h.nav.currentState!.pop();
        await tester.pumpAndSettle();
        final fresh = h.track(h.sheet.animateToDetent('short'));
        await tester.pumpAndSettle();
        expect(fresh.value, isTrue);
      }
      await h.clean(tester);
    });
  }

  testWidgets(
    'M13 equal height aliases retain distinct requested semantic rest',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(
        detents: [
          IosSheetDetent.height('short', 300),
          IosSheetDetent.height('alias', 300),
          IosSheetDetent.large,
        ],
      );
      await tester.pumpAndSettle();
      final a = h.track(h.sheet.animateToDetent('alias'));
      // ignore: invalid_use_of_protected_member
      expect(h.route.controller!.isAnimating, isTrue);
      await tester.pumpAndSettle();
      expect(a.value, isTrue);
      expect(h.sheet.restingDetentIdentifier, 'alias');
      await h.clean(tester);
    },
  );

  for (final interruption in ['engine', 'stop', 'value']) {
    testWidgets(
      'M14 $interruption interruption cannot become coordinate-only success',
      (tester) async {
        final h = _Harness();
        await h.present(tester);
        final a = h.track(h.sheet.animateToDetent('large'));
        // ignore: invalid_use_of_protected_member
        final engine = h.route.controller!;
        if (interruption == 'engine') {
          h.route.animateToRelative(1).orCancel.ignore();
        } else if (interruption == 'stop') {
          engine.stop();
        } else {
          engine.value = 1;
        }
        await tester.idle();
        expect(a.value, isFalse);
        await h.clean(tester);
      },
    );
  }

  testWidgets(
    'M15 final tick listener supersedes old success before its observer',
    (tester) async {
      final h = _Harness();
      await h.present(tester);
      _Probe<bool>? fresh;
      h.sheet.addListener(() {
        if (fresh == null && h.sheet.restingDetentIdentifier == 'large') {
          fresh = h.track(h.sheet.animateToDetent('short'));
        }
      });
      final old = h.track(h.sheet.animateToDetent('large'));
      await tester.pumpAndSettle();
      expect(old.value, isFalse);
      expect(fresh!.value, isTrue);
      expect(h.sheet.restingDetentIdentifier, 'short');
      await h.clean(tester);
    },
  );

  testWidgets(
    'M04 fixed opening and declined pop preserve valid attachment semantics',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(fixedOpening: true);
      final p = h.track(h.sheet.whenPresented());
      await tester.pump();
      expect(() => h.sheet.animateToDetent('missing'), throwsArgumentError);
      expect(() => h.sheet.animateToDetent('large'), throwsStateError);
      await tester.pumpAndSettle();
      expect(p.error, isNull);
      h.route.addLocalHistoryEntry(LocalHistoryEntry());
      final old = h.track(h.sheet.animateToDetent('large'));
      h.nav.currentState!.pop();
      await tester.idle();
      expect(old.done, isFalse);
      expect(h.sheet.isAttached, isTrue);
      expect(h.sheet.targetDetentIdentifier, 'large');
      await tester.pumpAndSettle();
      expect(old.value, isTrue);
      final fresh = h.track(h.sheet.animateToDetent('short'));
      await tester.pumpAndSettle();
      expect(fresh.value, isTrue);
      await h.clean(tester);
    },
  );

  for (final invalid in ['target', 'position', 'velocity']) {
    testWidgets('M05 invalid $invalid construction preserves prior ticker', (
      tester,
    ) async {
      final h = _Harness();
      final model = _LifecycleModel();
      await h.mount(tester);
      h.push(model: model);
      await tester.pumpAndSettle();
      final old = h.track(h.sheet.animateToDetent('large'));
      final state = h.sheet.snapshotState();
      model.invalid = invalid;
      expect(() => h.sheet.animateToDetent('short'), throwsStateError);
      model.invalid = null;
      expect(h.sheet.selectedDetentIdentifier, 'large');
      expect(h.sheet.snapshotState().motionRequest, same(state.motionRequest));
      expect(
        h.sheet.snapshotState().motionTargetPoints,
        state.motionTargetPoints,
      );
      await tester.idle();
      expect(old.done, isFalse);
      await tester.pumpAndSettle();
      expect(old.value, isTrue);
      await h.clean(tester);
    });
  }

  testWidgets(
    'M06 model dismissal rejects the outer request without stale rollback',
    (tester) async {
      final h = _Harness();
      final model = _LifecycleModel();
      await h.mount(tester);
      h.push(model: model);
      await tester.pumpAndSettle();
      final old = h.track(h.sheet.animateToDetent('large'));
      model.onCreate = () {
        model.onCreate = null;
        h.sheet.dismiss();
      };
      expect(() => h.sheet.animateToDetent('short'), throwsStateError);
      expect(h.sheet.targetDetentIdentifier, isNull);
      await tester.idle();
      expect(old.value, isFalse);
      await h.clean(tester);
    },
  );

  testWidgets(
    'M06 onPresented dismissal preserves presentation but cancels detent wait',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(onPresented: () => h.sheet.dismiss());
      final p = h.track(h.sheet.whenPresented());
      final a = h.track(h.sheet.animateToDetent('large'));
      await tester.pumpAndSettle();
      expect(p.done, isTrue);
      expect(p.error, isNull);
      expect(a.value, isFalse);
      await h.clean(tester);
    },
  );

  testWidgets('M07 private drag-start hook cancels before any value delta', (
    tester,
  ) async {
    final h = _Harness();
    await h.present(tester);
    final a = h.track(h.sheet.animateToDetent('large'));
    final height = h.sheet.unscaledTrajectoryHeight;
    bridge.dispatchSheetDragStart(h.route);
    expect(h.sheet.unscaledTrajectoryHeight, height);
    await tester.idle();
    expect(a.value, isFalse);
    await h.clean(tester);
  });

  testWidgets(
    'M13 old ticker and bridge callbacks cannot affect reused generation',
    (tester) async {
      final h = _Harness();
      await h.present(tester);
      final oldRoute = h.route;
      final old = h.track(h.sheet.animateToDetent('large'));
      final detached = h.track(h.sheet.whenDetached());
      h.nav.currentState!.removeRoute(oldRoute);
      await tester.pumpAndSettle();
      expect(detached.done, isTrue);
      h.push();
      await tester.pumpAndSettle();
      final fresh = h.track(h.sheet.animateToDetent('large'));
      bridge.dispatchSheetDragStart(oldRoute);
      bridge.dispatchSheetDragCancel(oldRoute);
      await tester.idle();
      expect(old.value, isFalse);
      expect(fresh.done, isFalse);
      await tester.pumpAndSettle();
      expect(fresh.value, isTrue);
      await h.clean(tester);
    },
  );

  testWidgets('M14 successful ticker with wrong semantic rest returns false', (
    tester,
  ) async {
    final h = _Harness();
    final model = _LifecycleModel();
    await h.mount(tester);
    h.push(model: model);
    await tester.pumpAndSettle();
    model.invalid = 'rest';
    final a = h.track(h.sheet.animateToDetent('large'));
    await tester.pumpAndSettle();
    expect(a.done, isTrue);
    expect(a.value, isFalse);
    await h.clean(tester);
  });

  testWidgets(
    'M06 selected callback errors remain synchronous after accepted motion',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      h.push(
        onSelected: (identifier) {
          if (identifier == 'large')
            throw StateError('expected selected failure');
        },
      );
      await tester.pumpAndSettle();
      expect(() => h.sheet.animateToDetent('large'), throwsStateError);
      expect(h.sheet.selectedDetentIdentifier, 'large');
      // ignore: invalid_use_of_protected_member
      expect(h.route.controller!.isAnimating, isTrue);
      final fresh = h.track(h.sheet.animateToDetent('short'));
      await tester.pumpAndSettle();
      expect(fresh.value, isTrue);
      await h.clean(tester);
    },
  );

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
