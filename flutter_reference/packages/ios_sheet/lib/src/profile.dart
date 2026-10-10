import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';
import 'package:ios_sheet_engine/ios_sheet_engine.dart';

import 'detents.dart';
import 'corner_bridge.dart';

/// The supported iOS sheet reference major version.
const iosSheetReferenceMajorVersion = 26;

/// Major versions supported by the strict sheet reference resolver.
const supportedIosSheetReferenceMajorVersions = {26};

/// Shares the legacy resolver with other libraries inside this package.
@internal
IosSheetProfile legacyIosSheetProfileForMajorVersion(int version) =>
    IosSheetProfile._profileForMajorVersion(version);

/// Independent OS profiles. Defaults are research fallbacks, not native truth.
@immutable
class IosSheetProfile {
  const IosSheetProfile({
    required this.majorVersion,
    required this.mediumHeight,
    required this.evidence,
    this.isMeasured = false,
    this.geometry = _fallbackGeometry,
    this.motion = const CupertinoMotion.smooth(snapToEnd: true),
    this.snapPhysics = const FlingSnapPhysics(),
    this.maximumDetentHeight = _fallbackMaximum,
    this.detentToVisibleHeight = _fallbackVisible,
    this.dragResistance,
    this.releaseResistance,
    this.fixedSurfaceDuringTransition = false,
  });

  static final ios26 = IosSheetProfile(
    majorVersion: 26,
    mediumHeight: _fallbackMedium,
    evidence: const {'medium': 'fallback: half maximum; native unmeasured'},
  );
  @Deprecated('iOS 27 is an unsupported legacy research fallback. Use ios26.')
  static final ios27 = _ios27;

  static final _ios27 = IosSheetProfile(
    majorVersion: 27,
    mediumHeight: _fallbackMedium,
    evidence: const {'medium': 'fallback: half maximum; iOS 27 unmeasured'},
  );

  /// Resolves only supported iOS sheet reference versions.
  static IosSheetProfile forReferenceVersion(int version) {
    if (version == iosSheetReferenceMajorVersion) return ios26;
    throw UnsupportedError('Only iOS 26 is a supported sheet reference');
  }

  @Deprecated('Use forReferenceVersion for the supported iOS 26 reference.')
  static IosSheetProfile forMajorVersion(int version) =>
      _profileForMajorVersion(version);

  static IosSheetProfile _profileForMajorVersion(int version) =>
      switch (version) {
        26 => ios26,
        27 => _ios27,
        _ => throw UnsupportedError('No sheet profile for iOS $version'),
      };

  static double _fallbackMedium(IosSheetEnvironment environment) =>
      environment.maximumDetentHeight / 2;

  static IosSheetGeometry _fallbackGeometry(IosSheetGeometryContext context) =>
      const IosSheetGeometry(cornerRadius: 24);
  static double _fallbackMaximum(IosSheetEnvironment environment) =>
      environment.maximumDetentHeight;
  static double _fallbackVisible(double height, IosSheetEnvironment _) =>
      height;

  final int majorVersion;
  final IosDetentResolver mediumHeight;
  final Map<String, String> evidence;
  final bool isMeasured;
  final IosSheetGeometryResolver geometry;
  final Motion motion;
  final SnapPhysics snapPhysics;
  final IosDetentResolver maximumDetentHeight;
  final IosDetentVisibleHeightResolver detentToVisibleHeight;

  /// Returns the applied finger delta in points. Null preserves upstream law.
  final IosResistanceResolver? dragResistance;

  /// Returns the release velocity in points/second. Null preserves upstream.
  final IosResistanceResolver? releaseResistance;
  final bool fixedSurfaceDuringTransition;

  IosSheetProfile copyWith({
    IosDetentResolver? mediumHeight,
    Map<String, String>? evidence,
    bool? isMeasured,
    IosSheetGeometryResolver? geometry,
    Motion? motion,
    SnapPhysics? snapPhysics,
    IosDetentResolver? maximumDetentHeight,
    IosDetentVisibleHeightResolver? detentToVisibleHeight,
    IosResistanceResolver? dragResistance,
    IosResistanceResolver? releaseResistance,
    bool? fixedSurfaceDuringTransition,
  }) => IosSheetProfile(
    majorVersion: majorVersion,
    mediumHeight: mediumHeight ?? this.mediumHeight,
    evidence: Map.unmodifiable({...this.evidence, ...?evidence}),
    isMeasured: isMeasured ?? this.isMeasured,
    geometry: geometry ?? this.geometry,
    motion: motion ?? this.motion,
    snapPhysics: snapPhysics ?? this.snapPhysics,
    maximumDetentHeight: maximumDetentHeight ?? this.maximumDetentHeight,
    detentToVisibleHeight: detentToVisibleHeight ?? this.detentToVisibleHeight,
    dragResistance: dragResistance ?? this.dragResistance,
    releaseResistance: releaseResistance ?? this.releaseResistance,
    fixedSurfaceDuringTransition:
        fixedSurfaceDuringTransition ?? this.fixedSurfaceDuringTransition,
  );
}

typedef IosDetentVisibleHeightResolver =
    double Function(double detentHeight, IosSheetEnvironment environment);
typedef IosResistanceResolver =
    double Function(IosSheetResistanceContext context);

@immutable
class IosSheetResistanceContext {
  const IosSheetResistanceContext({
    required this.positionPoints,
    required this.boundaryPoints,
    required this.input,
    required this.referenceHeight,
  });
  final double positionPoints;
  final double boundaryPoints;

  /// Finger delta in points or velocity in points/second, depending on callback.
  final double input;
  final double referenceHeight;
}

typedef IosSheetGeometryResolver =
    IosSheetGeometry Function(IosSheetGeometryContext context);

@immutable
class IosSheetGeometryContext {
  const IosSheetGeometryContext({
    required this.environment,
    required this.visibleHeight,
    required this.progress,
    this.velocity = 0,
    this.transitionFraction = 1,
  });
  final IosSheetEnvironment environment;
  final double visibleHeight;
  final double progress;
  final double velocity;

  /// Existing fixed-surface opening/dismissal translation, independent of shape.
  final double transitionFraction;
}

/// Per-frame geometry seam. A resolver can express measured continuous or
/// piecewise side/bottom spacing and shape evolution separately on each OS.
@immutable
class IosSheetGeometry {
  const IosSheetGeometry({
    this.sideInset = 0,
    this.bottomInset = 0,
    this.cornerRadius = 0,
    this.shape,
    this.scale = 1,
    this.cornerResolution,
  });
  final double sideInset;
  final double bottomInset;
  final double cornerRadius;
  final double scale;

  /// Supports measured paths when a single scalar radius is insufficient.
  final ShapeBorder? shape;

  /// Native model/configuration radii only; never implies contour acceptance.
  final IosSheetCornerResolution? cornerResolution;
}
