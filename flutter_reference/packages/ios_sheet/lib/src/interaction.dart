import 'package:flutter/widgets.dart';

import 'state.dart';

/// Where Flutter delivered a gesture. This identifies an observed origin; it
/// does not assert UIKit's private recognizer ownership or arbitration rule.
enum IosSheetInteractionOrigin {
  content,
  grabber,
  control,
  nestedScroll,
  pager,
}

/// The axis and sign basis used by all terms in one conservation equation.
/// A local coordinate basis cannot be mixed with window point measurements.
enum IosSheetCoordinateConvention {
  windowPointsXRightYDown,
  localPointsXRightYDown,
}

/// One independently observed point-space position and its source.
@immutable
class IosSheetPointMeasurement {
  const IosSheetPointMeasurement({
    required this.position,
    required this.provenance,
    required this.convention,
  });

  final Offset position;
  final String provenance;
  final IosSheetCoordinateConvention convention;
}

/// A native handoff rule is deliberately absent until an accepted trace maps
/// delivered input to measured sheet and scroll movement.
@immutable
class IosSheetHandoffMapping {
  const IosSheetHandoffMapping.unavailable(this.provenance)
    : capability = IosSheetCapabilityStatus.unavailable,
      rule = null;

  final IosSheetCapabilityStatus capability;
  final String provenance;

  /// Reserved for an accepted, public-observation mapping; null means that no
  /// guessed transfer/arbitration rule may be applied.
  final Object? rule;
}

/// Identity and origin of an actually delivered gesture start.
@immutable
class IosSheetGestureStart {
  const IosSheetGestureStart({
    required this.gestureId,
    required this.origin,
    required this.deliveredAt,
  }) : assert(gestureId != '');

  final String gestureId;
  final IosSheetInteractionOrigin origin;
  final Duration deliveredAt;
}

/// A delta from one delivered Flutter pointer event, rather than a requested
/// drag or a reconstructed native transfer.
@immutable
class IosSheetDeliveredDelta {
  const IosSheetDeliveredDelta({
    required this.gestureId,
    required this.delta,
    required this.deliveredAt,
    required this.provenance,
    required this.convention,
  }) : assert(gestureId != '');

  final String gestureId;
  final Offset delta;
  final Duration deliveredAt;
  final String provenance;
  final IosSheetCoordinateConvention convention;
}

/// Immutable ledger row. Movement is derived only from the supplied measured
/// positions, so a nonzero residual remains visible instead of being assigned
/// to a sheet or scroll owner.
@immutable
class IosSheetHandoffSample {
  const IosSheetHandoffSample({
    required this.gestureId,
    required this.origin,
    required this.deliveredDelta,
    required this.observedSheetDelta,
    required this.observedScrollDelta,
    required this.residualDelta,
    required this.mapping,
    required this.inputProvenance,
    required this.sheetMeasurementProvenance,
    required this.scrollMeasurementProvenance,
    required this.convention,
  });

  final String gestureId;
  final IosSheetInteractionOrigin origin;
  final Offset deliveredDelta;
  final Offset observedSheetDelta;
  final Offset observedScrollDelta;
  final Offset residualDelta;
  final IosSheetHandoffMapping mapping;
  final String inputProvenance;
  final String sheetMeasurementProvenance;
  final String scrollMeasurementProvenance;
  final IosSheetCoordinateConvention convention;
}

/// Tracks one delivered gesture at a time. It records accounting evidence but
/// does not choose whether a sheet, scrollable, pager, or control owns input.
class IosSheetHandoffLedger {
  IosSheetHandoffLedger({
    this.mapping = const IosSheetHandoffMapping.unavailable(
      'No accepted native transfer mapping is available.',
    ),
  });

  final IosSheetHandoffMapping mapping;
  IosSheetGestureStart? _active;
  Duration? _lastAcceptedAt;

  String? get activeGestureId => _active?.gestureId;

  void begin(IosSheetGestureStart start) {
    if (_active != null) {
      throw StateError('A delivered gesture is already active.');
    }
    _active = start;
    _lastAcceptedAt = null;
  }

  IosSheetHandoffSample record(
    IosSheetDeliveredDelta input, {
    required IosSheetPointMeasurement sheetBefore,
    required IosSheetPointMeasurement sheetAfter,
    required IosSheetPointMeasurement scrollBefore,
    required IosSheetPointMeasurement scrollAfter,
  }) {
    final active = _active;
    if (active == null || active.gestureId != input.gestureId) {
      throw StateError('Delivered delta does not match the active gesture.');
    }
    if (input.deliveredAt < active.deliveredAt) {
      throw StateError('Delivered delta predates the active gesture.');
    }
    if (_lastAcceptedAt != null && input.deliveredAt <= _lastAcceptedAt!) {
      throw StateError('Delivered delta is not newer than the prior sample.');
    }
    _validateInput(input);
    _validateMeasurement(sheetBefore, input.convention, 'sheet before');
    _validateMeasurement(sheetAfter, input.convention, 'sheet after');
    _validateMeasurement(scrollBefore, input.convention, 'scroll before');
    _validateMeasurement(scrollAfter, input.convention, 'scroll after');

    final sheetDelta = sheetAfter.position - sheetBefore.position;
    final scrollDelta = scrollAfter.position - scrollBefore.position;
    final residual = input.delta - sheetDelta - scrollDelta;
    _lastAcceptedAt = input.deliveredAt;
    return IosSheetHandoffSample(
      gestureId: input.gestureId,
      origin: active.origin,
      deliveredDelta: input.delta,
      observedSheetDelta: sheetDelta,
      observedScrollDelta: scrollDelta,
      residualDelta: residual,
      mapping: mapping,
      inputProvenance: input.provenance,
      sheetMeasurementProvenance:
          '${sheetBefore.provenance}; ${sheetAfter.provenance}',
      scrollMeasurementProvenance:
          '${scrollBefore.provenance}; ${scrollAfter.provenance}',
      convention: input.convention,
    );
  }

  void cancel(String gestureId) {
    _requireActive(gestureId);
    _active = null;
    _lastAcceptedAt = null;
  }

  void reset() {
    _active = null;
    _lastAcceptedAt = null;
  }

  static void _validateInput(IosSheetDeliveredDelta input) {
    if (input.provenance.isEmpty) {
      throw ArgumentError.value(
        input.provenance,
        'provenance',
        'must not be empty',
      );
    }
    if (!_isFinite(input.delta)) {
      throw ArgumentError.value(input.delta, 'delta', 'must be finite');
    }
  }

  static void _validateMeasurement(
    IosSheetPointMeasurement measurement,
    IosSheetCoordinateConvention convention,
    String label,
  ) {
    if (measurement.provenance.isEmpty) {
      throw ArgumentError.value(
        measurement.provenance,
        label,
        'provenance is required',
      );
    }
    if (measurement.convention != convention) {
      throw ArgumentError.value(
        measurement.convention,
        label,
        'coordinate convention mismatch',
      );
    }
    if (!_isFinite(measurement.position)) {
      throw ArgumentError.value(
        measurement.position,
        label,
        'position must be finite',
      );
    }
  }

  static bool _isFinite(Offset value) => value.dx.isFinite && value.dy.isFinite;

  void _requireActive(String gestureId) {
    if (_active == null || _active!.gestureId != gestureId) {
      throw StateError('Gesture is not active.');
    }
  }
}

enum IosSheetWidgetEvent { pointer, scroll }

/// A passive widget-level observation. Pointer and scroll callbacks are
/// separate public Flutter observations and are never promoted to ownership.
@immutable
class IosSheetWidgetObservation {
  const IosSheetWidgetObservation({
    required this.kind,
    required this.origin,
    required this.deliveredAt,
    required this.provenance,
    this.pointerPosition,
    this.pointerDelta,
    this.scrollOffset,
  });

  final IosSheetWidgetEvent kind;
  final IosSheetInteractionOrigin origin;
  final Duration deliveredAt;
  final String provenance;
  final Offset? pointerPosition;
  final Offset? pointerDelta;
  final double? scrollOffset;
}

/// Passively reports real Flutter pointer delivery and scroll notifications for
/// one subtree. It does not consume input or alter gesture-arena arbitration.
class IosSheetScrollHandoffObserver extends StatelessWidget {
  const IosSheetScrollHandoffObserver({
    required this.origin,
    required this.onObservation,
    required this.child,
    super.key,
  });

  final IosSheetInteractionOrigin origin;
  final ValueChanged<IosSheetWidgetObservation> onObservation;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          onObservation(
            IosSheetWidgetObservation(
              kind: IosSheetWidgetEvent.scroll,
              origin: origin,
              deliveredAt: Duration.zero,
              provenance: 'Flutter ScrollNotification metrics',
              scrollOffset: notification.metrics.pixels,
            ),
          );
          return false;
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _observePointer,
          onPointerMove: _observePointer,
          onPointerUp: _observePointer,
          onPointerCancel: _observePointer,
          child: child,
        ),
      );

  void _observePointer(PointerEvent event) {
    onObservation(
      IosSheetWidgetObservation(
        kind: IosSheetWidgetEvent.pointer,
        origin: origin,
        deliveredAt: event.timeStamp,
        provenance: 'Flutter Listener delivered pointer event',
        pointerPosition: event.position,
        pointerDelta: event.delta,
      ),
    );
  }
}
