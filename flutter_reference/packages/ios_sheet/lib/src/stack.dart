import 'dart:collection';

import 'package:flutter/material.dart';

/// Whether an observation was recorded, is explicitly inapplicable, or absent.
enum IosSheetObservationAvailability { observed, unavailable, notApplicable }

/// The outcome reported by an actual focus observation for one route lifetime.
enum IosSheetFocusOutcome { focused, dismissed }

/// Immutable observations supplied for one sheet layer.
///
/// This deliberately records caller-observed values only. It does not derive a
/// rear layer's geometry, contour, eligibility, or provenance from its front
/// neighbour, and it does not model a UIKit transform.
@immutable
class IosSheetLayerObservation {
  const IosSheetLayerObservation({
    this.geometry,
    required this.geometryAvailability,
    required this.contourAvailability,
    this.barrierEligible,
    required this.barrierAvailability,
    this.hitTestEligible,
    required this.hitTestAvailability,
    this.semanticsEligible,
    required this.semanticsAvailability,
    this.liveProvenance,
    this.snapshotProvenance,
  });

  final Rect? geometry;
  final IosSheetObservationAvailability geometryAvailability;
  final IosSheetObservationAvailability contourAvailability;
  final bool? barrierEligible;
  final IosSheetObservationAvailability barrierAvailability;
  final bool? hitTestEligible;
  final IosSheetObservationAvailability hitTestAvailability;
  final bool? semanticsEligible;
  final IosSheetObservationAvailability semanticsAvailability;
  final String? liveProvenance;
  final String? snapshotProvenance;

  bool get isCoherent {
    bool hasCoherentValue({
      required Object? value,
      required IosSheetObservationAvailability availability,
    }) => availability == IosSheetObservationAvailability.observed
        ? value != null
        : value == null;

    final hasObservedValue =
        geometryAvailability == IosSheetObservationAvailability.observed ||
        contourAvailability == IosSheetObservationAvailability.observed ||
        barrierAvailability == IosSheetObservationAvailability.observed ||
        hitTestAvailability == IosSheetObservationAvailability.observed ||
        semanticsAvailability == IosSheetObservationAvailability.observed;
    return hasCoherentValue(
          value: geometry,
          availability: geometryAvailability,
        ) &&
        hasCoherentValue(
          value: barrierEligible,
          availability: barrierAvailability,
        ) &&
        hasCoherentValue(
          value: hitTestEligible,
          availability: hitTestAvailability,
        ) &&
        hasCoherentValue(
          value: semanticsEligible,
          availability: semanticsAvailability,
        ) &&
        (!hasObservedValue ||
            (liveProvenance?.trim().isNotEmpty ?? false) &&
                (snapshotProvenance?.trim().isNotEmpty ?? false));
  }
}

/// Immutable observation for one navigator route lifetime.
@immutable
class IosSheetLayerSnapshot {
  const IosSheetLayerSnapshot({
    required this.layerId,
    required this.isFront,
    required this.geometry,
    required this.geometryAvailability,
    required this.contourAvailability,
    required this.barrierEligible,
    required this.barrierAvailability,
    required this.hitTestEligible,
    required this.hitTestAvailability,
    required this.semanticsEligible,
    required this.semanticsAvailability,
    required this.focused,
    required this.focusAvailability,
    required this.focusOutcome,
    required this.focusProvenance,
    required this.liveProvenance,
    required this.snapshotProvenance,
  });

  final String layerId;
  final bool isFront;
  final Rect? geometry;
  final IosSheetObservationAvailability geometryAvailability;
  final IosSheetObservationAvailability contourAvailability;
  final bool? barrierEligible;
  final IosSheetObservationAvailability barrierAvailability;
  final bool? hitTestEligible;
  final IosSheetObservationAvailability hitTestAvailability;
  final bool? semanticsEligible;
  final IosSheetObservationAvailability semanticsAvailability;
  final bool? focused;
  final IosSheetObservationAvailability focusAvailability;
  final IosSheetFocusOutcome? focusOutcome;
  final String? focusProvenance;
  final String? liveProvenance;
  final String? snapshotProvenance;

  IosSheetLayerSnapshot copyWith({
    bool? isFront,
    Rect? geometry,
    IosSheetObservationAvailability? geometryAvailability,
    IosSheetObservationAvailability? contourAvailability,
    bool? barrierEligible,
    IosSheetObservationAvailability? barrierAvailability,
    bool? hitTestEligible,
    IosSheetObservationAvailability? hitTestAvailability,
    bool? semanticsEligible,
    IosSheetObservationAvailability? semanticsAvailability,
    bool? focused,
    IosSheetObservationAvailability? focusAvailability,
    IosSheetFocusOutcome? focusOutcome,
    String? focusProvenance,
    String? liveProvenance,
    String? snapshotProvenance,
  }) => IosSheetLayerSnapshot(
    layerId: layerId,
    isFront: isFront ?? this.isFront,
    geometry: geometry ?? this.geometry,
    geometryAvailability: geometryAvailability ?? this.geometryAvailability,
    contourAvailability: contourAvailability ?? this.contourAvailability,
    barrierEligible: barrierEligible ?? this.barrierEligible,
    barrierAvailability: barrierAvailability ?? this.barrierAvailability,
    hitTestEligible: hitTestEligible ?? this.hitTestEligible,
    hitTestAvailability: hitTestAvailability ?? this.hitTestAvailability,
    semanticsEligible: semanticsEligible ?? this.semanticsEligible,
    semanticsAvailability: semanticsAvailability ?? this.semanticsAvailability,
    focused: focused ?? this.focused,
    focusAvailability: focusAvailability ?? this.focusAvailability,
    focusOutcome: focusOutcome ?? this.focusOutcome,
    focusProvenance: focusProvenance ?? this.focusProvenance,
    liveProvenance: liveProvenance ?? this.liveProvenance,
    snapshotProvenance: snapshotProvenance ?? this.snapshotProvenance,
  );
}

/// A rear-to-front immutable stack observation.
@immutable
class IosSheetStackSnapshot {
  IosSheetStackSnapshot(List<IosSheetLayerSnapshot> layers)
    : layers = UnmodifiableListView(layers);

  final List<IosSheetLayerSnapshot> layers;
}

/// Navigator lifetime observer for private, not-yet-integrated stack evidence.
class IosSheetLayerStackObserver extends NavigatorObserver {
  final List<_LayerRecord> _records = <_LayerRecord>[];
  final Map<Route<dynamic>, _LayerRecord> _recordsByRoute =
      <Route<dynamic>, _LayerRecord>{};
  int _nextId = 0;

  IosSheetStackSnapshot get snapshot => IosSheetStackSnapshot(
    List<IosSheetLayerSnapshot>.generate(
      _records.length,
      (index) => _records[index].snapshot.copyWith(
        isFront: index == _records.length - 1,
      ),
      growable: false,
    ),
  );

  /// Returns the current generation token for [route], if it is active.
  String? layerIdForRoute(Route<dynamic> route) =>
      _recordsByRoute[route]?.snapshot.layerId;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _insert(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remove(route);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remove(route);
    super.didRemove(route, previousRoute);
  }

  /// Records an observation only while [route] is still an active layer.
  bool observeLayer(
    Route<dynamic> route,
    String layerId,
    IosSheetLayerObservation observation,
  ) {
    final record = _recordsByRoute[route];
    if (record == null ||
        record.snapshot.layerId != layerId ||
        !observation.isCoherent) {
      return false;
    }
    record.snapshot = IosSheetLayerSnapshot(
      layerId: record.snapshot.layerId,
      isFront: record.snapshot.isFront,
      geometry: observation.geometry,
      geometryAvailability: observation.geometryAvailability,
      contourAvailability: observation.contourAvailability,
      barrierEligible: observation.barrierEligible,
      barrierAvailability: observation.barrierAvailability,
      hitTestEligible: observation.hitTestEligible,
      hitTestAvailability: observation.hitTestAvailability,
      semanticsEligible: observation.semanticsEligible,
      semanticsAvailability: observation.semanticsAvailability,
      focused: record.snapshot.focused,
      focusAvailability: record.snapshot.focusAvailability,
      focusOutcome: record.snapshot.focusOutcome,
      focusProvenance: record.snapshot.focusProvenance,
      liveProvenance: observation.liveProvenance,
      snapshotProvenance: observation.snapshotProvenance,
    );
    return true;
  }

  /// Records a focus result only for the current front layer.
  bool recordTopFocusOutcome(
    Route<dynamic> route,
    String layerId, {
    required IosSheetFocusOutcome outcome,
    required bool focused,
    required String provenance,
  }) {
    if (_records.isEmpty ||
        !identical(_records.last.route, route) ||
        _records.last.snapshot.layerId != layerId ||
        provenance.trim().isEmpty ||
        (outcome == IosSheetFocusOutcome.focused && !focused) ||
        (outcome == IosSheetFocusOutcome.dismissed && focused)) {
      return false;
    }
    final record = _records.last;
    record.snapshot = record.snapshot.copyWith(
      focused: focused,
      focusAvailability: IosSheetObservationAvailability.observed,
      focusOutcome: outcome,
      focusProvenance: provenance,
    );
    return true;
  }

  void _insert(Route<dynamic> route) {
    if (_recordsByRoute.containsKey(route)) return;
    final record = _LayerRecord(
      route,
      IosSheetLayerSnapshot(
        layerId: 'sheet-layer-${_nextId++}',
        isFront: false,
        geometry: null,
        geometryAvailability: IosSheetObservationAvailability.unavailable,
        contourAvailability: IosSheetObservationAvailability.unavailable,
        barrierEligible: null,
        barrierAvailability: IosSheetObservationAvailability.unavailable,
        hitTestEligible: null,
        hitTestAvailability: IosSheetObservationAvailability.unavailable,
        semanticsEligible: null,
        semanticsAvailability: IosSheetObservationAvailability.unavailable,
        focused: null,
        focusAvailability: IosSheetObservationAvailability.unavailable,
        focusOutcome: null,
        focusProvenance: null,
        liveProvenance: null,
        snapshotProvenance: null,
      ),
    );
    _records.add(record);
    _recordsByRoute[route] = record;
  }

  void _remove(Route<dynamic> route) {
    final record = _recordsByRoute.remove(route);
    if (record != null) _records.remove(record);
  }
}

class _LayerRecord {
  _LayerRecord(this.route, this.snapshot);

  final Route<dynamic> route;
  IosSheetLayerSnapshot snapshot;
}
