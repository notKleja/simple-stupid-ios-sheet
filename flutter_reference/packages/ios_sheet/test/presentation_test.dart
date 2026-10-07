import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  late IosSheetController sheet;
  late int activations;
  final observations = <IosSheetUnderlyingHitObservation>[];
  Future<void> present(
    WidgetTester tester, {
    bool field = false,
    FocusNode? focus,
    bool controlInside = false,
    bool transparentModal = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigator = GlobalKey<NavigatorState>();
    sheet = IosSheetController();
    activations = 0;
    observations.clear();
    void activated() {
      activations++;
      sheet.recordUnderlyingControlActivation('underlying');
    }

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.only(top: 60),
            viewPadding: EdgeInsets.only(top: 60),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: controlInside ? 600 : 0,
                left: 100,
                width: 200,
                child: field
                    ? TextField(focusNode: focus, onTap: activated)
                    : TextButton(
                        onPressed: activated,
                        child: const Text('Underlying control'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    navigator.currentState!.push(
      StupidSimpleIosSheetRoute<void>(
        profile: IosSheetProfile.ios26,
        dismissible: false,
        controller: sheet,
        detents: const [IosSheetDetent.medium, IosSheetDetent.large],
        initialDetentIdentifier: 'medium',
        largestUndimmedDetentIdentifier: transparentModal ? null : 'medium',
        modalBarrierColor: transparentModal
            ? Colors.transparent
            : const Color.fromRGBO(0, 0, 0, .2),
        onUnderlyingHitObserved: observations.add,
        child: const Center(child: Text('Sheet surface')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<bool?> tapProbe(WidgetTester tester, String id, Offset point) async {
    sheet.beginUnderlyingControlProbe(
      probeIdentifier: id,
      controlIdentifier: 'underlying',
      position: point,
    );
    await tester.tapAt(point);
    return sheet.completeUnderlyingControlProbe()?.activated;
  }

  testWidgets(
    'actual control activates medium large medium with separate presentation outputs',
    (tester) async {
      await present(tester);
      final point = tester.getCenter(find.text('Underlying control'));
      expect(sheet.captureFrame().state['underlying_hit_test'], isNull);
      final medium = sheet.snapshotState().presentation!;
      expect(medium.effectiveBarrierAlpha, 0);
      expect(medium.underlyingPointerEligible, isTrue);
      expect(medium.underlyingSemanticsEligible, isTrue);
      expect(medium.capability, IosSheetCapabilityStatus.fallback);
      expect(await tapProbe(tester, 'medium-initial', point), isTrue);
      sheet.selectDetent('large');
      await tester.pumpAndSettle();
      final large = sheet.snapshotState().presentation!;
      expect(
        large.sheetBounds!.contains(point),
        isFalse,
      ); // Barrier, not sheet, blocks this point.
      expect(large.effectiveBarrierAlpha, closeTo(.2, 1e-8));
      expect(large.underlyingPointerEligible, isFalse);
      expect(large.underlyingSemanticsEligible, isFalse);
      expect(await tapProbe(tester, 'large', point), isFalse);
      expect(sheet.captureFrame().state['underlying_hit_test'], isFalse);
      sheet.selectDetent('medium');
      await tester.pumpAndSettle();
      expect(await tapProbe(tester, 'medium-return', point), isTrue);
      expect(activations, 2);
      expect(observations.map((value) => value.activated), [true, false, true]);
      expect(sheet.captureFrame().state['underlying_hit_test'], isTrue);
    },
  );

  testWidgets('no delivered probe leaves observed hit test unknown', (
    tester,
  ) async {
    await present(tester);
    final point = tester.getCenter(find.text('Underlying control'));
    sheet.beginUnderlyingControlProbe(
      probeIdentifier: 'not-delivered',
      controlIdentifier: 'underlying',
      position: point,
    );
    expect(sheet.completeUnderlyingControlProbe(), isNull);
    expect(sheet.captureFrame().state['underlying_hit_test'], isNull);
    expect(sheet.captureFrame().unavailable['underlying_hit_test'], isNotEmpty);
    expect(observations, isEmpty);
  });

  testWidgets('completed blocked probe cannot absorb a later independent tap', (
    tester,
  ) async {
    await present(tester);
    final point = tester.getCenter(find.text('Underlying control'));
    sheet.selectDetent('large');
    await tester.pumpAndSettle();
    sheet.beginUnderlyingControlProbe(
      probeIdentifier: 'blocked-original',
      controlIdentifier: 'underlying',
      position: point,
    );
    await tester.tapAt(point);
    expect(activations, 0);

    sheet.selectDetent('medium');
    await tester.pumpAndSettle();
    await tester.tapAt(point);
    expect(activations, 1); // Independent real control activation.
    final original = sheet.completeUnderlyingControlProbe()!;
    expect(original.probeIdentifier, 'blocked-original');
    expect(original.activated, isFalse);
    expect(observations.map((value) => value.activated), [false]);
    expect(sheet.captureFrame().state['underlying_hit_test'], isFalse);
  });

  testWidgets('cancelled pointer stream leaves observed hit test unknown', (
    tester,
  ) async {
    await present(tester);
    final point = tester.getCenter(find.text('Underlying control'));
    sheet.beginUnderlyingControlProbe(
      probeIdentifier: 'cancelled',
      controlIdentifier: 'underlying',
      position: point,
    );
    final gesture = await tester.startGesture(point);
    await gesture.cancel();
    expect(activations, 0);
    expect(sheet.completeUnderlyingControlProbe(), isNull);
    expect(observations, isEmpty);
    expect(sheet.captureFrame().state['underlying_hit_test'], isNull);
  });

  testWidgets('non-tap stream returning to its origin is not a completed tap', (
    tester,
  ) async {
    await present(tester);
    final point = tester.getCenter(find.text('Underlying control'));
    sheet.beginUnderlyingControlProbe(
      probeIdentifier: 'drag-return',
      controlIdentifier: 'underlying',
      position: point,
    );
    final gesture = await tester.startGesture(point);
    await gesture.moveBy(const Offset(80, 80));
    await gesture.moveBy(const Offset(-80, -80));
    await gesture.up();
    expect(activations, 0);
    expect(sheet.completeUnderlyingControlProbe(), isNull);
    expect(observations, isEmpty);
    expect(sheet.captureFrame().state['underlying_hit_test'], isNull);
  });

  testWidgets(
    'underlying control inside rendered sheet does not click through',
    (tester) async {
      await present(tester, controlInside: true);
      final point = tester.getCenter(find.text('Underlying control'));
      expect(
        sheet.snapshotState().presentation!.sheetBounds!.contains(point),
        isTrue,
      );
      expect(await tapProbe(tester, 'inside-sheet', point), isFalse);
      expect(activations, 0);
    },
  );

  testWidgets(
    'outside-sheet text field receives actual focus in undimmed state',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await present(tester, field: true, focus: focus);
      final point = tester.getCenter(find.byType(TextField));
      expect(
        sheet.snapshotState().presentation!.sheetBounds!.contains(point),
        isFalse,
      );
      expect(await tapProbe(tester, 'focus', point), isTrue);
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    },
  );

  testWidgets('zero-alpha modal barrier still blocks actual control input', (
    tester,
  ) async {
    await present(tester, transparentModal: true);
    final state = sheet.snapshotState().presentation!;
    expect(state.effectiveBarrierAlpha, 0);
    expect(state.underlyingPointerEligible, isFalse);
    expect(state.underlyingSemanticsEligible, isFalse);
    final point = tester.getCenter(find.text('Underlying control'));
    expect(await tapProbe(tester, 'transparent-modal', point), isFalse);
    expect(activations, 0);
  });
}
