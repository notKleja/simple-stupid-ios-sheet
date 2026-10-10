import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum IosSheetOrientation { unknown, portrait, landscape, portraitUpsideDown }

enum IosSheetSizeClass { unknown, compact, regular }

@immutable
class IosSheetStackContext {
  const IosSheetStackContext({
    this.depth,
    this.isTopmost,
    this.parentIdentifier,
  });
  final int? depth;
  final bool? isTopmost;
  final String? parentIdentifier;
  @override
  bool operator ==(Object other) =>
      other is IosSheetStackContext &&
      depth == other.depth &&
      isTopmost == other.isTopmost &&
      parentIdentifier == other.parentIdentifier;
  @override
  int get hashCode => Object.hash(depth, isTopmost, parentIdentifier);
}

/// Immutable layout and observed traits, in logical points.
/// Null/unknown is unobserved; applied avoidance is not keyboard observation.
@immutable
class IosSheetEnvironment {
  const IosSheetEnvironment({
    required this.availableSize,
    required this.maximumDetentHeight,
    this.safeArea = EdgeInsets.zero,
    double keyboardHeight = 0,
    double? appliedKeyboardAvoidance,
    this.observedKeyboardFrame,
    this.observedKeyboardHeight,
    this.contentHeight,
    this.displayScale = 1,
    this.orientation = IosSheetOrientation.unknown,
    this.horizontalSizeClass = IosSheetSizeClass.unknown,
    this.verticalSizeClass = IosSheetSizeClass.unknown,
    this.textScale,
    this.contentSizeCategory,
    this.reduceMotion,
    this.platformBrightness,
    this.locale,
    this.textDirection,
    this.stack = const IosSheetStackContext(),
  }) : keyboardHeight = appliedKeyboardAvoidance ?? keyboardHeight;

  final Size availableSize;
  final double maximumDetentHeight;
  final EdgeInsets safeArea;

  /// Source-compatible legacy name for policy-applied avoidance only.
  final double keyboardHeight;
  double get appliedKeyboardAvoidance => keyboardHeight;
  final Rect? observedKeyboardFrame;

  /// Observed obscured height; does not imply a keyboard rectangle was measured.
  final double? observedKeyboardHeight;
  final double? contentHeight;
  final double displayScale;
  final IosSheetOrientation orientation;
  final IosSheetSizeClass horizontalSizeClass;
  final IosSheetSizeClass verticalSizeClass;

  /// Linear text multiplier, null for nonlinear/unavailable scaling.
  final double? textScale;
  final String? contentSizeCategory;
  final bool? reduceMotion;
  final Brightness? platformBrightness;
  final Locale? locale;
  final TextDirection? textDirection;
  final IosSheetStackContext stack;

  /// Rebase the existing layout maximum without losing observed traits.
  IosSheetEnvironment withMaximumDetentHeight(double maximum) =>
      IosSheetEnvironment(
        availableSize: availableSize,
        maximumDetentHeight: maximum,
        safeArea: safeArea,
        appliedKeyboardAvoidance: keyboardHeight,
        observedKeyboardFrame: observedKeyboardFrame,
        observedKeyboardHeight: observedKeyboardHeight,
        contentHeight: contentHeight,
        displayScale: displayScale,
        orientation: orientation,
        horizontalSizeClass: horizontalSizeClass,
        verticalSizeClass: verticalSizeClass,
        textScale: textScale,
        contentSizeCategory: contentSizeCategory,
        reduceMotion: reduceMotion,
        platformBrightness: platformBrightness,
        locale: locale,
        textDirection: textDirection,
        stack: stack,
      );

  List<Object?> get _identity => [
    availableSize,
    maximumDetentHeight,
    safeArea,
    keyboardHeight,
    observedKeyboardFrame,
    observedKeyboardHeight,
    contentHeight,
    displayScale,
    orientation,
    horizontalSizeClass,
    verticalSizeClass,
    textScale,
    contentSizeCategory,
    reduceMotion,
    platformBrightness,
    locale,
    textDirection,
    stack,
  ];
  @override
  bool operator ==(Object other) =>
      other is IosSheetEnvironment && listEquals(_identity, other._identity);
  @override
  int get hashCode => Object.hashAll(_identity);

  /// Physical-pixel-quantized geometric inputs plus exact observed traits.
  IosSheetEnvironmentKey get cacheKey {
    final keyboard = observedKeyboardFrame;
    return IosSheetEnvironmentKey._([
      quantizeIosSheetPoint(availableSize.width, displayScale),
      quantizeIosSheetPoint(availableSize.height, displayScale),
      quantizeIosSheetPoint(maximumDetentHeight, displayScale),
      for (final value in [
        safeArea.left,
        safeArea.top,
        safeArea.right,
        safeArea.bottom,
        keyboardHeight,
        observedKeyboardHeight,
        contentHeight,
        keyboard?.left,
        keyboard?.top,
        keyboard?.right,
        keyboard?.bottom,
      ])
        value == null ? null : quantizeIosSheetPoint(value, displayScale),
      displayScale,
      orientation,
      horizontalSizeClass,
      verticalSizeClass,
      textScale,
      contentSizeCategory,
      reduceMotion,
      platformBrightness,
      locale,
      textDirection,
      stack,
    ]);
  }
}

@immutable
class IosSheetEnvironmentKey {
  IosSheetEnvironmentKey._(List<Object?> values)
    : _values = List.unmodifiable(values);
  final List<Object?> _values;
  @override
  bool operator ==(Object other) =>
      other is IosSheetEnvironmentKey && listEquals(_values, other._values);
  @override
  int get hashCode => Object.hashAll(_values);
}

/// Quantization is a cache identity rule, not a native geometry formula.
int quantizeIosSheetPoint(double point, double scale) {
  if (!point.isFinite ||
      !scale.isFinite ||
      scale <= 0 ||
      !(point * scale).isFinite) {
    throw ArgumentError(
      'Corner cache requires finite points and positive display scale',
    );
  }
  return (point * scale).round();
}
