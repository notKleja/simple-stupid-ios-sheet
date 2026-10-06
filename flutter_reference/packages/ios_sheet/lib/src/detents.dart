import 'package:flutter/widgets.dart';

import 'profile.dart';

/// Runtime layout inputs. Heights are logical points, not physical pixels.
@immutable
class IosSheetEnvironment {
  const IosSheetEnvironment({
    required this.availableSize,
    required this.maximumDetentHeight,
    this.safeArea = EdgeInsets.zero,
    this.keyboardHeight = 0,
    this.contentHeight,
  });

  final Size availableSize;
  final double maximumDetentHeight;
  final EdgeInsets safeArea;
  final double keyboardHeight;
  final double? contentHeight;
}

typedef IosDetentResolver = double Function(IosSheetEnvironment environment);

/// A semantic identifier plus a point-based resolver.
///
/// Medium is resolved by the selected OS profile; it is never implicitly a
/// fraction in this API. Fractions explicitly use maximumDetentHeight.
@immutable
class IosSheetDetent {
  const IosSheetDetent._(this.identifier, this._kind, this._resolver);

  static const medium = IosSheetDetent._('medium', _DetentKind.medium, null);
  static const large = IosSheetDetent._('large', _DetentKind.large, null);

  factory IosSheetDetent.height(String identifier, double height) =>
      IosSheetDetent.custom(identifier, (_) => height);

  factory IosSheetDetent.fraction(String identifier, double fraction) {
    if (!fraction.isFinite || fraction <= 0 || fraction > 1) {
      throw ArgumentError.value(fraction, 'fraction', 'must be in (0, 1]');
    }
    return IosSheetDetent.custom(
      identifier,
      (environment) => environment.maximumDetentHeight * fraction,
    );
  }

  factory IosSheetDetent.custom(String identifier, IosDetentResolver resolver) {
    if (identifier.isEmpty) throw ArgumentError('Detent identifier is empty');
    return IosSheetDetent._(identifier, _DetentKind.custom, resolver);
  }

  final String identifier;
  final _DetentKind _kind;
  final IosDetentResolver? _resolver;
}

enum _DetentKind { medium, large, custom }

@immutable
class ResolvedIosDetent {
  const ResolvedIosDetent(this.identifier, this.height, this.relativeExtent);

  final String identifier;
  final double height;
  final double relativeExtent;
}

/// Validates, resolves, and sorts by height. Identical heights remain separate
/// semantic identifiers; the engine may deduplicate their relative extents.
List<ResolvedIosDetent> resolveIosDetents(
  List<IosSheetDetent> detents, {
  required IosSheetEnvironment environment,
  required IosSheetProfile profile,
}) {
  final maximum = environment.maximumDetentHeight;
  if (!maximum.isFinite || maximum <= 0) {
    throw ArgumentError.value(maximum, 'maximumDetentHeight');
  }
  if (detents.isEmpty) throw ArgumentError('At least one detent is required');
  final identifiers = <String>{};
  final result = <ResolvedIosDetent>[];
  for (final detent in detents) {
    if (!identifiers.add(detent.identifier)) {
      throw ArgumentError('Duplicate detent identifier: ${detent.identifier}');
    }
    final height = switch (detent._kind) {
      _DetentKind.medium => profile.mediumHeight(environment),
      _DetentKind.large => maximum,
      _DetentKind.custom => detent._resolver!(environment),
    };
    if (!height.isFinite || height <= 0) {
      throw ArgumentError.value(height, detent.identifier, 'invalid height');
    }
    final boundedHeight = height.clamp(0.0, maximum);
    result.add(
      ResolvedIosDetent(
        detent.identifier,
        boundedHeight,
        boundedHeight / maximum,
      ),
    );
  }
  result.sort((a, b) => a.height.compareTo(b.height));
  return List.unmodifiable(result);
}
