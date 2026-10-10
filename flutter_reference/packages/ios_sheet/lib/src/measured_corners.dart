import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/widgets.dart';

import 'corner_bridge.dart';
import 'environment.dart';

/// Synchronous model/configuration radii, not rendered-contour measurement.
/// Explicit opt-in scope: iPhone17Pro portrait page sizing, 402x874@3x,
/// safe62/34 and observed hidden keyboard. Device identity/page configuration
/// must be selected by the caller; geometry alone is not hardware detection.
/// The asynchronous platform bridge remains independent of this paint seam.
@immutable
class IosSheetPage402x874CornerModel {
  const IosSheetPage402x874CornerModel({required this.majorVersion});
  final int majorVersion;
  double get minimumTop => 62;
  double get maximumTop => 874;
  double get minimumWidth => 385.9999999999999;
  double get maximumWidth => 402;
  double get minimumHeight => 339.91044776119406;
  double get maximumHeight => 812;
  double get minimumSideInset => 0;
  double get maximumSideInset => 8.000000000000028;
  double get minimumBottomInset => -450.97346600331684;
  double get maximumBottomInset => 8;
  double get bottomHoldoutMaxError => .2532201404456984;
  String get provenance =>
      'native_reference/radius_transfer.json@f299569; SHA256 '
      '164ab02e1660a2a60b8786ba21913880eb8da535006142976223a38d3f55e8af; '
      'iPhone17Pro portrait page402x874@3x safe62/34 keyboard hidden; '
      'model/configuration points only; full recorded top/width/height/side/bottom domain; '
      'TL/TR holdout error0; BL/BR holdout max error0.2532201404456984pt; '
      'rendered contour unresolved; no Flutter parity claim';

  IosSheetCornerResolution resolve(IosSheetCornerRequest request) {
    IosSheetCornerResolution unavailable(String reason) =>
        IosSheetCornerResolution.unavailable(reason: reason);
    if (majorVersion != 26) {
      return unavailable(
        'iOS$majorVersion four-corner model unavailable: bottom corners unresolved',
      );
    }
    final env = request.environment;
    if (env.availableSize != const Size(402, 874) ||
        env.safeArea != const EdgeInsets.only(top: 62, bottom: 34) ||
        env.displayScale != 3 ||
        env.orientation != IosSheetOrientation.portrait ||
        env.keyboardHeight != 0 ||
        env.observedKeyboardHeight != 0 ||
        (env.observedKeyboardFrame?.height ?? 0) != 0) {
      return unavailable(
        'Outside measured portrait page402x874@3x safe62/34 hidden-keyboard scope',
      );
    }
    final frame = request.frame;
    if ([
          frame.left,
          frame.top,
          frame.right,
          frame.bottom,
          frame.width,
          frame.height,
        ].any((value) => !value.isFinite || value < 0) ||
        frame.width == 0 ||
        frame.height == 0) {
      return unavailable(
        'Invalid frame: finite nonnegative coordinates and positive size required',
      );
    }
    final top = frame.top;
    final side = math.min(frame.left, env.availableSize.width - frame.right);
    final bottomInset = env.availableSize.height - frame.bottom;
    // Only floating-point arithmetic tolerance, not a native fit tolerance or
    // permission to extrapolate. Exact f299569 domain endpoints are retained.
    bool within(double value, double minimum, double maximum) =>
        value.isFinite &&
        value >= minimum - precisionErrorTolerance &&
        value <= maximum + precisionErrorTolerance;
    if (!within(top, minimumTop, maximumTop) ||
        !within(frame.width, minimumWidth, maximumWidth) ||
        !within(frame.height, minimumHeight, maximumHeight) ||
        !within(side, minimumSideInset, maximumSideInset) ||
        !within(bottomInset, minimumBottomInset, maximumBottomInset)) {
      return unavailable(
        'Frame is outside recorded top/width/height/side/bottom domains; no extrapolation',
      );
    }
    final bottom = 63.17638970202942 - .01707456471577085 * top;
    return IosSheetCornerResolution.resolved(
      IosSheetCornerRadii(
        topLeft: const Radius.circular(38),
        topRight: const Radius.circular(38),
        bottomRight: Radius.circular(bottom),
        bottomLeft: Radius.circular(bottom),
      ),
      provenance: provenance,
    );
  }
}
