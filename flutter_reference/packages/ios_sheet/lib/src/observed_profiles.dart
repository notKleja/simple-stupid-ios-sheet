import 'package:flutter/widgets.dart';

import 'detents.dart';
import 'profile.dart';

/// Partial profile qualified by 10 repeated native traces on EACH OS.
///
/// Scope: iPhone simulator 402x874 @3x, safe top62/bottom34, portrait,
/// keyboard hidden, page sizing, [fixed320, medium, large]. Other geometries
/// fail explicitly. Radius, barrier, timing, gestures, and interruption remain
/// upstream fallbacks. This is not an OS-wide native-parity profile.
///
/// Source: native_reference/measurements.json and SHA-linked native traces.
/// Width/bottom transfer fits are PROVISIONAL: the native animation recorder
/// was found to mix incoherent ancestry/geometry. Only the resting samples are
/// usable; these transfer hypotheses must be replaced after fresh collection.
IosSheetProfile observedPage402x874Profile(int majorVersion) {
  final fallback = IosSheetProfile.forMajorVersion(majorVersion);
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
      return IosSheetGeometry(
        scale: scale,
        bottomInset: bottom,
        cornerRadius: 24,
      ); // Explicit unmeasured upstream shape fallback.
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
      'corner': 'fallback: upstream SheetBackground24; no native radius claim',
    },
  );
}
