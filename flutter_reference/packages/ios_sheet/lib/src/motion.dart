import 'package:flutter/widgets.dart';
import 'package:ios_sheet_engine/ios_sheet_engine.dart';
import 'environment.dart';
import 'state.dart';

enum IosSheetMotionKind {
  presentation,
  detentSnap,
  overdragReturn,
  dismissal,
  environmentRebase,
  keyboardRebase,
  contentInvalidation,
}

enum IosSheetVelocitySource { controller, dragRelease }

/// Logical unscaled extent-height axis: positive expands the sheet.
/// This is not window-Y motion inferred through the unmeasured visual map.
@immutable
class IosSheetMotionRequest {
  const IosSheetMotionRequest({
    required this.kind,
    required this.positionPoints,
    required this.velocityPointsPerSecond,
    required this.targetPoints,
    required this.referenceHeightPoints,
    required this.velocitySource,
    required this.environment,
    this.dragReleaseVelocityPointsPerSecond,
  });
  final IosSheetMotionKind kind;
  final double positionPoints,
      velocityPointsPerSecond,
      targetPoints,
      referenceHeightPoints;

  /// Observed release after the existing resistance transfer, when present.
  final double? dragReleaseVelocityPointsPerSecond;
  final IosSheetVelocitySource velocitySource;
  final IosSheetEnvironment environment;
}

@immutable
class IosSheetTrajectory {
  const IosSheetTrajectory({
    required this.simulation,
    required this.targetPoints,
    required this.provenance,
    required this.capability,
  });

  /// x is logical extent points, dx is points/second.
  final Simulation simulation;
  final double targetPoints;
  final String provenance;
  final IosSheetCapabilityStatus capability;
}

abstract interface class IosSheetTrajectoryModel {
  IosSheetTrajectory createTrajectory(IosSheetMotionRequest request);
}

/// Current Motion adapter, not a native trajectory or calibrated parameter set.
class FallbackIosSheetTrajectoryModel implements IosSheetTrajectoryModel {
  const FallbackIosSheetTrajectoryModel(this.motion);
  final Motion motion;
  @override
  IosSheetTrajectory createTrajectory(IosSheetMotionRequest request) {
    final height = request.referenceHeightPoints;
    if (!height.isFinite || height <= 0)
      throw ArgumentError('Positive finite reference height required');
    final legacy = motion.createSimulation(
      start: request.positionPoints / height,
      end: request.targetPoints / height,
      velocity: request.velocityPointsPerSecond / height,
    );
    return IosSheetTrajectory(
      simulation: _ScaledSimulation(legacy, height),
      targetPoints: request.targetPoints,
      provenance:
          'unchanged upstream Motion law; unmeasured fallback, not native dynamics',
      capability: IosSheetCapabilityStatus.fallback,
    );
  }
}

/// Converts a point-space model back to the existing normalized controller axis.
Simulation normalizeIosSheetTrajectory(
  IosSheetTrajectory trajectory,
  double referenceHeightPoints,
) => _ScaledSimulation(trajectory.simulation, 1 / referenceHeightPoints);

class _ScaledSimulation extends Simulation {
  _ScaledSimulation(this.inner, this.scale) : super(tolerance: inner.tolerance);
  final Simulation inner;
  final double scale;
  @override
  double x(double time) => inner.x(time) * scale;
  @override
  double dx(double time) => inner.dx(time) * scale;
  @override
  bool isDone(double time) => inner.isDone(time);
}
