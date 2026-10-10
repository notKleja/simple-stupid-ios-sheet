import 'package:flutter/widgets.dart';
import 'environment.dart';
import 'motion.dart';
import 'presentation.dart';

enum IosSheetPhase {
  presenting,
  presented,
  dragging,
  snapping,
  dismissing,
  dismissed,
}

enum IosSheetGestureState { none, touch }

enum IosSheetCapabilityStatus { unavailable, fallback, observed, accepted }

@immutable
class IosSheetScrollObservation {
  const IosSheetScrollObservation({
    this.offset,
    this.velocity,
    this.observedMovementConsumer,
    this.owner,
  });
  final double? offset;
  final double? velocity;
  final String? observedMovementConsumer;
  final String? owner;
}

/// An observation, not a new layout or motion driver.
/// Frame/position are logical window points; velocity is points/second when
/// actually observed. A normalized engine velocity must not be substituted.
@immutable
class IosSheetState {
  IosSheetState({
    required this.frame,
    required this.velocity,
    required this.phase,
    required this.selectedDetent,
    required this.targetDetent,
    required this.restingDetent,
    required this.gesture,
    required this.sheetDragging,
    required this.scroll,
    required this.environment,
    required Map<String, IosSheetCapabilityStatus> capabilities,
    required Map<String, String> provenance,
    this.motionRequest,
    this.motionTargetPoints,
    this.presentation,
  }) : capabilities = Map.unmodifiable(capabilities),
       provenance = Map.unmodifiable(provenance);
  final Rect frame;
  Offset get position => frame.topLeft;
  final Offset? velocity;
  final IosSheetPhase phase;
  final String? selectedDetent;
  final String? targetDetent;
  final String? restingDetent;
  final IosSheetGestureState gesture;
  final bool sheetDragging;
  final IosSheetScrollObservation scroll;
  final IosSheetEnvironment environment;
  final Map<String, IosSheetCapabilityStatus> capabilities;
  final Map<String, String> provenance;
  final IosSheetMotionRequest? motionRequest;
  final double? motionTargetPoints;
  final IosSheetPresentationState? presentation;
}
