import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'state.dart';

@immutable
class IosSheetPresentationState {
  const IosSheetPresentationState({
    required this.effectiveBarrierAlpha,
    required this.underlyingPointerEligible,
    required this.underlyingSemanticsEligible,
    required this.sheetBounds,
    required this.capability,
    required this.provenance,
  });
  final double effectiveBarrierAlpha;
  final bool underlyingPointerEligible;
  final bool underlyingSemanticsEligible;
  final Rect? sheetBounds;
  final IosSheetCapabilityStatus capability;
  final String provenance;
  bool allowsUnderlyingPointerAt(Offset point) =>
      underlyingPointerEligible &&
      sheetBounds != null &&
      !sheetBounds!.contains(point);
}

/// Result of one completed, actually delivered tap and matching control callback.
/// This is not a continuous hit mask or configured eligibility boolean.
@immutable
class IosSheetUnderlyingHitObservation {
  const IosSheetUnderlyingHitObservation._({
    required this.probeIdentifier,
    required this.controlIdentifier,
    required this.position,
    required this.activated,
    required this.deliveredAt,
  });
  final String probeIdentifier, controlIdentifier;
  final Offset position;
  final bool activated;
  final Duration deliveredAt;
}

/// Scoped passive pointer observation. Never consumes input or joins an arena.
class IosSheetUnderlyingControlProbe {
  IosSheetUnderlyingControlProbe({
    required this.probeIdentifier,
    required this.controlIdentifier,
    required this.position,
    required this.viewId,
  }) {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_observe);
  }
  final String probeIdentifier, controlIdentifier;
  final Offset position;
  final int viewId;
  int? _pointer;
  Duration? _completedAt;
  bool _cancelled = false, _activated = false, _disposed = false;
  void _observe(PointerEvent event) {
    if (event.viewId != viewId) return;
    if (event is PointerDownEvent &&
        event.position == position &&
        _pointer == null)
      _pointer = event.pointer;
    if (event.pointer != _pointer) return;
    if (event is PointerCancelEvent) _cancelled = true;
    if (event is PointerUpEvent && event.position == position)
      _completedAt = event.timeStamp;
  }

  /// Call only from the real underlying control activation callback.
  void recordControlActivation(String identifier) {
    if (!_disposed &&
        !_cancelled &&
        _pointer != null &&
        identifier == controlIdentifier)
      _activated = true;
  }

  IosSheetUnderlyingHitObservation? complete() {
    dispose();
    if (_completedAt == null || _cancelled) return null;
    return IosSheetUnderlyingHitObservation._(
      probeIdentifier: probeIdentifier,
      controlIdentifier: controlIdentifier,
      position: position,
      activated: _activated,
      deliveredAt: _completedAt!,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_observe);
  }
}

/// Reads current policy at hit time, not a prior barrier build's cached flag.
class IosSheetLiveBarrierRouting extends SingleChildRenderObjectWidget {
  const IosSheetLiveBarrierRouting({
    required this.presentation,
    required super.child,
    super.key,
  });
  final ValueGetter<IosSheetPresentationState> presentation;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LiveBarrierRouting(presentation);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _LiveBarrierRouting renderObject,
  ) {
    renderObject.presentation = presentation;
  }
}

class _LiveBarrierRouting extends RenderProxyBox {
  _LiveBarrierRouting(this.presentation);
  ValueGetter<IosSheetPresentationState> presentation;
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (presentation().allowsUnderlyingPointerAt(localToGlobal(position)))
      return false;
    return super.hitTest(result, position: position);
  }
}
