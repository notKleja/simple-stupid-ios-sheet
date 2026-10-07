import 'package:flutter/widgets.dart';
import 'environment.dart';

/// Four radii in logical points; physical pixels are used only for cache keys.
@immutable
class IosSheetCornerRadii {
  const IosSheetCornerRadii({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });
  final Radius topLeft, topRight, bottomRight, bottomLeft;

  /// Clockwise from top-left. No scalar-radius equivalence is assumed.
  List<Radius> get clockwise =>
      List.unmodifiable([topLeft, topRight, bottomRight, bottomLeft]);
}

enum IosSheetCornerStatus { resolved, unavailable }

/// A provider result is not a native-acceptance claim.
@immutable
class IosSheetCornerResolution {
  const IosSheetCornerResolution._(
    this.status,
    this.radii,
    this.reason,
    this.provenance,
  );
  factory IosSheetCornerResolution.resolved(
    IosSheetCornerRadii radii, {
    required String provenance,
  }) {
    if (provenance.trim().isEmpty ||
        radii.clockwise.any(
          (radius) =>
              !radius.x.isFinite ||
              !radius.y.isFinite ||
              radius.x < 0 ||
              radius.y < 0,
        )) {
      throw ArgumentError(
        'Resolved corners require finite nonnegative radii and provenance',
      );
    }
    return IosSheetCornerResolution._(
      IosSheetCornerStatus.resolved,
      radii,
      null,
      provenance,
    );
  }
  factory IosSheetCornerResolution.unavailable({required String reason}) {
    if (reason.trim().isEmpty)
      throw ArgumentError('Unavailable corners require a reason');
    return IosSheetCornerResolution._(
      IosSheetCornerStatus.unavailable,
      null,
      reason,
      null,
    );
  }
  final IosSheetCornerStatus status;
  final IosSheetCornerRadii? radii;
  final String? reason;
  final String? provenance;
}

@immutable
class IosSheetCornerRequest {
  const IosSheetCornerRequest({required this.environment, required this.frame});
  final IosSheetEnvironment environment;
  final Rect frame;
  IosSheetCornerKey get key => IosSheetCornerKey(
    environment: environment.cacheKey,
    left: quantizeIosSheetPoint(frame.left, environment.displayScale),
    top: quantizeIosSheetPoint(frame.top, environment.displayScale),
    right: quantizeIosSheetPoint(frame.right, environment.displayScale),
    bottom: quantizeIosSheetPoint(frame.bottom, environment.displayScale),
  );
}

@immutable
class IosSheetCornerKey {
  const IosSheetCornerKey({
    required this.environment,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
  final IosSheetEnvironmentKey environment;
  final int left, top, right, bottom;
  @override
  bool operator ==(Object other) =>
      other is IosSheetCornerKey &&
      environment == other.environment &&
      left == other.left &&
      top == other.top &&
      right == other.right &&
      bottom == other.bottom;
  @override
  int get hashCode => Object.hash(environment, left, top, right, bottom);
}

abstract interface class IosSheetCornerResolver {
  Future<Map<IosSheetCornerKey, IosSheetCornerResolution>> resolveBatch(
    List<IosSheetCornerRequest> requests,
  );
}

class UnavailableIosSheetCornerResolver implements IosSheetCornerResolver {
  const UnavailableIosSheetCornerResolver();
  @override
  Future<Map<IosSheetCornerKey, IosSheetCornerResolution>> resolveBatch(
    List<IosSheetCornerRequest> requests,
  ) async => {
    for (final request in requests)
      request.key: IosSheetCornerResolution.unavailable(
        reason: 'Native four-corner resolver is not connected',
      ),
  };
}

/// Async injection seam only; no platform formula, radius default, or layout use.
class IosSheetCornerBridge {
  const IosSheetCornerBridge({
    this.resolver = const UnavailableIosSheetCornerResolver(),
  });
  final IosSheetCornerResolver resolver;
  Future<Map<IosSheetCornerKey, IosSheetCornerResolution>> resolveBatch(
    List<IosSheetCornerRequest> requests,
  ) async {
    final unique = <IosSheetCornerKey, IosSheetCornerRequest>{};
    for (final request in requests) {
      unique.putIfAbsent(request.key, () => request);
    }
    final results = await resolver.resolveBatch(
      List.unmodifiable(unique.values),
    );
    if (results.keys.any((key) => !unique.containsKey(key))) {
      throw StateError('Corner resolver returned an unrequested physical key');
    }
    return Map.unmodifiable({
      for (final key in unique.keys)
        key:
            results[key] ??
            IosSheetCornerResolution.unavailable(
              reason: 'Resolver omitted this physical frame',
            ),
    });
  }
}
