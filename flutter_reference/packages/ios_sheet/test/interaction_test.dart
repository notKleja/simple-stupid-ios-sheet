import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/src/interaction.dart';
import '../lib/src/state.dart';

IosSheetPointMeasurement measurement(
  double x,
  double y, {
  String provenance = 'measured public Flutter position',
  IosSheetCoordinateConvention convention =
      IosSheetCoordinateConvention.windowPointsXRightYDown,
}) => IosSheetPointMeasurement(
  position: Offset(x, y),
  provenance: provenance,
  convention: convention,
);

void main() {
  group('IosSheetHandoffLedger', () {
    test('missing native transfer mapping stays unavailable', () {
      const mapping = IosSheetHandoffMapping.unavailable(
        'no accepted native handoff trace',
      );

      expect(mapping.capability, IosSheetCapabilityStatus.unavailable);
      expect(mapping.rule, isNull);
      expect(mapping.provenance, contains('no accepted native'));
    });

    test('accounts only delivered input and measured positions', () {
      final ledger = IosSheetHandoffLedger();
      ledger.begin(
        const IosSheetGestureStart(
          gestureId: 'content-1',
          origin: IosSheetInteractionOrigin.content,
          deliveredAt: Duration.zero,
        ),
      );

      final sample = ledger.record(
        const IosSheetDeliveredDelta(
          gestureId: 'content-1',
          delta: Offset(0, 30),
          deliveredAt: Duration(milliseconds: 16),
          provenance: 'delivered Flutter pointer event',
          convention: IosSheetCoordinateConvention.windowPointsXRightYDown,
        ),
        sheetBefore: measurement(0, 100),
        sheetAfter: measurement(0, 112),
        scrollBefore: measurement(0, 20),
        scrollAfter: measurement(0, 31),
      );

      expect(sample.observedSheetDelta, const Offset(0, 12));
      expect(sample.observedScrollDelta, const Offset(0, 11));
      expect(sample.residualDelta, const Offset(0, 7));
      expect(sample.mapping.capability, IosSheetCapabilityStatus.unavailable);
      expect(sample.origin, IosSheetInteractionOrigin.content);
      expect(sample.sheetMeasurementProvenance, isNotEmpty);
      expect(sample.scrollMeasurementProvenance, isNotEmpty);
      expect(
        sample.convention,
        IosSheetCoordinateConvention.windowPointsXRightYDown,
      );
    });

    test('rejects a stale gesture identity after reset', () {
      final ledger = IosSheetHandoffLedger();
      ledger.begin(
        const IosSheetGestureStart(
          gestureId: 'first',
          origin: IosSheetInteractionOrigin.grabber,
          deliveredAt: Duration.zero,
        ),
      );
      ledger.reset();

      expect(
        () => ledger.record(
          const IosSheetDeliveredDelta(
            gestureId: 'first',
            delta: Offset(0, 10),
            deliveredAt: Duration(milliseconds: 1),
            provenance: 'delivered Flutter pointer event',
            convention: IosSheetCoordinateConvention.windowPointsXRightYDown,
          ),
          sheetBefore: measurement(0, 0),
          sheetAfter: measurement(0, 10),
          scrollBefore: measurement(0, 0),
          scrollAfter: measurement(0, 0),
        ),
        throwsStateError,
      );
    });

    test(
      'cancel clears the active gesture and a second gesture can reverse',
      () {
        final ledger = IosSheetHandoffLedger();
        ledger.begin(
          const IosSheetGestureStart(
            gestureId: 'first',
            origin: IosSheetInteractionOrigin.control,
            deliveredAt: Duration.zero,
          ),
        );
        ledger.cancel('first');
        ledger.begin(
          const IosSheetGestureStart(
            gestureId: 'second',
            origin: IosSheetInteractionOrigin.pager,
            deliveredAt: Duration(milliseconds: 20),
          ),
        );

        final sample = ledger.record(
          const IosSheetDeliveredDelta(
            gestureId: 'second',
            delta: Offset(-4, -20),
            deliveredAt: Duration(milliseconds: 36),
            provenance: 'delivered Flutter pointer event',
            convention: IosSheetCoordinateConvention.windowPointsXRightYDown,
          ),
          sheetBefore: measurement(10, 100),
          sheetAfter: measurement(8, 92),
          scrollBefore: measurement(0, 10),
          scrollAfter: measurement(-1, 3),
        );

        expect(sample.residualDelta, const Offset(-1, -5));
        expect(sample.origin, IosSheetInteractionOrigin.pager);
      },
    );

    test(
      'preserves diagonal accounting and nested origin without ownership claim',
      () {
        final ledger = IosSheetHandoffLedger();
        ledger.begin(
          const IosSheetGestureStart(
            gestureId: 'nested-diagonal',
            origin: IosSheetInteractionOrigin.nestedScroll,
            deliveredAt: Duration.zero,
          ),
        );

        final sample = ledger.record(
          const IosSheetDeliveredDelta(
            gestureId: 'nested-diagonal',
            delta: Offset(8, -20),
            deliveredAt: Duration(milliseconds: 16),
            provenance: 'delivered Flutter pointer event',
            convention: IosSheetCoordinateConvention.windowPointsXRightYDown,
          ),
          sheetBefore: measurement(0, 0),
          sheetAfter: measurement(2, -9),
          scrollBefore: measurement(0, 0),
          scrollAfter: measurement(4, -6),
        );

        expect(sample.residualDelta, const Offset(2, -5));
        expect(sample.mapping.capability, IosSheetCapabilityStatus.unavailable);
      },
    );
    test('rejects nonfinite delivered and measured point-space values', () {
      final ledger = IosSheetHandoffLedger();
      ledger.begin(
        const IosSheetGestureStart(
          gestureId: 'finite',
          origin: IosSheetInteractionOrigin.content,
          deliveredAt: Duration.zero,
        ),
      );

      expect(
        () => ledger.record(
          const IosSheetDeliveredDelta(
            gestureId: 'finite',
            delta: Offset(double.nan, 1),
            deliveredAt: Duration(milliseconds: 1),
            provenance: 'delivered Flutter pointer event',
            convention: IosSheetCoordinateConvention.windowPointsXRightYDown,
          ),
          sheetBefore: measurement(0, 0),
          sheetAfter: measurement(0, 0),
          scrollBefore: measurement(0, 0),
          scrollAfter: measurement(0, 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => ledger.record(
          const IosSheetDeliveredDelta(
            gestureId: 'finite',
            delta: Offset(0, 1),
            deliveredAt: Duration(milliseconds: 2),
            provenance: 'delivered Flutter pointer event',
            convention: IosSheetCoordinateConvention.windowPointsXRightYDown,
          ),
          sheetBefore: measurement(double.infinity, 0),
          sheetAfter: measurement(0, 0),
          scrollBefore: measurement(0, 0),
          scrollAfter: measurement(0, 0),
        ),
        throwsArgumentError,
      );
    });

    test(
      'rejects missing provenance and mismatched coordinate conventions',
      () {
        final ledger = IosSheetHandoffLedger();
        ledger.begin(
          const IosSheetGestureStart(
            gestureId: 'convention',
            origin: IosSheetInteractionOrigin.content,
            deliveredAt: Duration.zero,
          ),
        );
        const input = IosSheetDeliveredDelta(
          gestureId: 'convention',
          delta: Offset(0, 1),
          deliveredAt: Duration(milliseconds: 1),
          provenance: 'delivered Flutter pointer event',
          convention: IosSheetCoordinateConvention.windowPointsXRightYDown,
        );

        expect(
          () => ledger.record(
            input,
            sheetBefore: measurement(0, 0, provenance: ''),
            sheetAfter: measurement(0, 0),
            scrollBefore: measurement(0, 0),
            scrollAfter: measurement(0, 0),
          ),
          throwsArgumentError,
        );
        expect(
          () => ledger.record(
            input,
            sheetBefore: measurement(
              0,
              0,
              convention: IosSheetCoordinateConvention.localPointsXRightYDown,
            ),
            sheetAfter: measurement(0, 0),
            scrollBefore: measurement(0, 0),
            scrollAfter: measurement(0, 0),
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'rejects equal or backward sample times and clears them by lifecycle',
      () {
        final ledger = IosSheetHandoffLedger();
        ledger.begin(
          const IosSheetGestureStart(
            gestureId: 'ordered',
            origin: IosSheetInteractionOrigin.grabber,
            deliveredAt: Duration.zero,
          ),
        );
        IosSheetDeliveredDelta input(Duration deliveredAt) =>
            IosSheetDeliveredDelta(
              gestureId: 'ordered',
              delta: const Offset(0, 1),
              deliveredAt: deliveredAt,
              provenance: 'delivered Flutter pointer event',
              convention: IosSheetCoordinateConvention.windowPointsXRightYDown,
            );
        IosSheetHandoffSample record(Duration deliveredAt) => ledger.record(
          input(deliveredAt),
          sheetBefore: measurement(0, 0),
          sheetAfter: measurement(0, 0),
          scrollBefore: measurement(0, 0),
          scrollAfter: measurement(0, 0),
        );

        record(const Duration(milliseconds: 10));
        expect(
          () => record(const Duration(milliseconds: 10)),
          throwsStateError,
        );
        expect(() => record(const Duration(milliseconds: 9)), throwsStateError);
        ledger.cancel('ordered');
        ledger.begin(
          const IosSheetGestureStart(
            gestureId: 'ordered',
            origin: IosSheetInteractionOrigin.grabber,
            deliveredAt: Duration.zero,
          ),
        );
        expect(record(const Duration(milliseconds: 1)).gestureId, 'ordered');
        ledger.reset();
        ledger.begin(
          const IosSheetGestureStart(
            gestureId: 'ordered',
            origin: IosSheetInteractionOrigin.grabber,
            deliveredAt: Duration.zero,
          ),
        );
        expect(record(const Duration(milliseconds: 1)).gestureId, 'ordered');
      },
    );
  });

  testWidgets('widget observer reports delivered pointer and scroll outcomes', (
    tester,
  ) async {
    final observations = <IosSheetWidgetObservation>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IosSheetScrollHandoffObserver(
            origin: IosSheetInteractionOrigin.content,
            onObservation: observations.add,
            child: ListView.builder(
              itemCount: 30,
              itemBuilder: (_, index) =>
                  SizedBox(height: 48, child: Text('row $index')),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('row 0'), const Offset(0, -180));
    await tester.pump();

    expect(
      observations.where((value) => value.kind == IosSheetWidgetEvent.pointer),
      isNotEmpty,
    );
    expect(
      observations.where((value) => value.kind == IosSheetWidgetEvent.scroll),
      isNotEmpty,
    );
    expect(
      observations
          .where((value) => value.kind == IosSheetWidgetEvent.scroll)
          .every((value) => value.scrollOffset != null),
      isTrue,
    );
  });
}
