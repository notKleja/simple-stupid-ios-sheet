import 'package:flutter/widgets.dart';

import 'detents.dart';
import 'profile.dart';
import 'corner_bridge.dart';
import 'measured_corners.dart';

/// Partial iOS 26 reference profile for the observed 402x874 page geometry.
///
/// Retains the scoped evidence and provisional transfer hypotheses of
/// [observedPage402x874Profile]; full native parity remains unverified.
IosSheetProfile observedIos26Page402x874Profile() =>
    _observedPage402x874Profile(iosSheetReferenceMajorVersion);

/// Partial profile qualified by 10 repeated native traces on EACH OS.
///
/// Scope: iPhone simulator 402x874 @3x, safe top62/bottom34, portrait,
/// keyboard hidden, page sizing, `fixed320`, `medium`, `large`. Other geometries
/// fail explicitly. Rendered contour, barrier, timing, gestures, and interruption remain
/// upstream fallbacks. This is not an OS-wide native-parity profile.
///
/// Source: native_reference/measurements.json and SHA-linked native traces.
/// Width/bottom transfer fits are PROVISIONAL: the native animation recorder
/// was found to mix incoherent ancestry/geometry. Only the resting samples are
/// usable; these transfer hypotheses must be replaced after fresh collection.
@Deprecated('Use observedIos26Page402x874Profile for the iOS 26 reference.')
IosSheetProfile observedPage402x874Profile(int majorVersion) =>
    _observedPage402x874Profile(majorVersion);

IosSheetProfile _observedPage402x874Profile(int majorVersion) {
  final fallback = legacyIosSheetProfileForMajorVersion(majorVersion);
  void requireScope(IosSheetEnvironment environment) {
    if (environment.availableSize != const Size(402, 874) ||
        environment.safeArea.top != 62 ||
        environment.safeArea.bottom != 34 ||
        environment.displayScale != 3 ||
        environment.keyboardHeight != 0) {
      throw UnsupportedError(
        'Measured profile requires 402x874 @3x, '
        'safe62/34, portrait and no keyboard',
      );
    }
  }

  return fallback.copyWith(
    maximumDetentHeight: (environment) {
      requireScope(environment);
      return environment.maximumDetentHeight - environment.safeArea.bottom;
    },
    mediumHeight: (environment) {
      requireScope(environment);
      return environment.maximumDetentHeight * .56;
    },
    detentToVisibleHeight: (height, environment) {
      requireScope(environment);
      return ((height + environment.safeArea.bottom) * environment.displayScale)
              .round() /
          environment.displayScale;
    },
    geometry: (context) {
      requireScope(context.environment);
      // Native reference maximum visible height: 778 + safeBottom34 = 812.
      // Medium is rounded to the native physical-pixel grid before scaling.
      const maximumVisible = 812.0;
      const mediumVisible = 1409 / 3;
      const width = 402.0;
      const inset = 8.0;
      final side =
          (inset *
                  (1 - context.progress) /
                  (1 - mediumVisible / maximumVisible))
              .clamp(0.0, inset);
      final scale = (width - 2 * side) / width;
      // Provisional recorded-container hypothesis, NOT accepted native motion.
      // Native recorder ancestry defects require independent recollection.
      final bottom = majorVersion == 27 && context.velocity < 0
          ? side
          : side +
                ((maximumVisible - mediumVisible) / width) *
                    side *
                    (1 - side / inset);
      // Acyclic: shape consumes exactly the final scale/bottom/surface transform;
      // no detent identifier or prior rendered-frame sample selects the model.
      final surfaceHeight = context.visibleHeight * scale;
      final transitionOffset =
          (1 - context.transitionFraction) * (surfaceHeight + bottom);
      final top =
          context.environment.availableSize.height -
          context.environment.keyboardHeight -
          surfaceHeight -
          bottom +
          transitionOffset;
      final corners = IosSheetPage402x874CornerModel(majorVersion: majorVersion)
          .resolve(
            IosSheetCornerRequest(
              environment: context.environment,
              frame: Rect.fromLTWH(side, top, width * scale, surfaceHeight),
            ),
          );
      final radii = corners.radii;
      return IosSheetGeometry(
        scale: scale,
        bottomInset: bottom,
        cornerRadius: 24,
        cornerResolution: corners,
        shape: radii == null
            ? null
            : RoundedSuperellipseBorder(
                borderRadius: BorderRadius.only(
                  topLeft: radii.topLeft,
                  topRight: radii.topRight,
                  bottomRight: radii.bottomRight,
                  bottomLeft: radii.bottomLeft,
                ),
              ),
      ); // Closest Flutter continuous shape, not accepted native contour.
    },
    fixedSurfaceDuringTransition: true,
    evidence: {
      'scope':
          'native_reference/measurements.json; 10 trials per OS; '
          'native.medium_large.programmatic; geometry402x874 only',
      'medium': 'measured:435.68/778 on both OS profiles independently',
      'detentGeometry':
          'derived: native detent +safeBottom, physical-pixel grid',
      'scale': 'derived from native container bounds; medium386/402, large1',
      'sideTransfer':
          'hypothesis: invalidated native trajectory recorder; '
          'linear model must be remeasured over [1409/2436,1]',
      'bottomTransfer':
          'hypothesis: recorded26 quadratic both directions; 27 linear down, '
          'quadratic up; recorder coordinate defects invalidate acceptance',
      'belowMedium': 'fallback: clamp to observed medium boundary; unmeasured',
      'presentationGeometry':
          'measured: surface height/width stay fixed; '
          'translation trajectory remains upstream motion fallback',
      'corner': majorVersion == 26
          ? IosSheetPage402x874CornerModel(majorVersion: 26).provenance
          : 'unavailable: iOS27 bottom corners unresolved; visible fallback24',
    },
  );
}
