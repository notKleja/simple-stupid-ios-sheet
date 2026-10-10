import 'package:flutter/widgets.dart';

import 'detents.dart';
import 'profile.dart';
import 'state.dart';

/// The observed source of a detent invalidation.
///
/// These reasons share one atomic update path; they are not animation modes.
enum IosSheetContentInvalidationReason { content, keyboard, dynamicType }

/// The outcome of a proposed content-size invalidation.
enum IosSheetContentAdaptationStatus {
  applied,
  staleTransaction,
  invalidContentHeight,
  invalidReasons,
  semanticSelectionMismatch,
  missingSemanticSelection,
  contentDetentMismatch,
  resolutionFailed,
}

/// An immutable update point for eventual native-derived detent rebasing.
@immutable
class IosSheetContentSnapshot {
  IosSheetContentSnapshot({
    required this.transaction,
    required this.selectedDetent,
    required List<ResolvedIosDetent> resolvedDetents,
    required this.position,
    required this.velocity,
    required this.phase,
    required Set<IosSheetContentInvalidationReason> reasons,
    this.contentHeight,
  }) : resolvedDetents = List.unmodifiable(resolvedDetents),
       reasons = Set.unmodifiable(reasons);

  final int transaction;
  final String selectedDetent;
  final List<ResolvedIosDetent> resolvedDetents;
  final Offset position;
  final Offset? velocity;
  final IosSheetPhase phase;
  final Set<IosSheetContentInvalidationReason> reasons;
  final double? contentHeight;
}

/// A result that always exposes the currently committed snapshot.
@immutable
class IosSheetContentAdaptationResult {
  const IosSheetContentAdaptationResult(this.status, this.snapshot);

  final IosSheetContentAdaptationStatus status;
  final IosSheetContentSnapshot snapshot;
}

/// Applies fully-resolved detent updates atomically.
///
/// It stores position and velocity without creating or driving any animation.
/// A route/state owner can later pass the committed snapshot into a
/// native-derived rebase once a supported mapping has been observed.
class IosSheetContentAdaptation {
  IosSheetContentAdaptation({required IosSheetContentSnapshot snapshot})
    : _snapshot = snapshot;

  IosSheetContentSnapshot _snapshot;

  IosSheetContentSnapshot get snapshot => _snapshot;

  IosSheetContentAdaptationResult invalidate({
    required int transaction,
    required String selectedDetent,
    required double contentHeight,
    required String contentDetent,
    required List<IosSheetDetent> detents,
    required IosSheetEnvironment environment,
    required IosSheetProfile profile,
    required IosSheetPhase phase,
    required Set<IosSheetContentInvalidationReason> reasons,
  }) {
    if (transaction <= _snapshot.transaction) {
      return _result(IosSheetContentAdaptationStatus.staleTransaction);
    }
    if (!contentHeight.isFinite || contentHeight <= 0) {
      return _result(IosSheetContentAdaptationStatus.invalidContentHeight);
    }
    if (reasons.isEmpty) {
      return _result(IosSheetContentAdaptationStatus.invalidReasons);
    }
    if (selectedDetent.isEmpty) {
      return _result(IosSheetContentAdaptationStatus.missingSemanticSelection);
    }
    if (selectedDetent != _snapshot.selectedDetent) {
      return _result(IosSheetContentAdaptationStatus.semanticSelectionMismatch);
    }

    final List<ResolvedIosDetent> resolved;
    try {
      resolved = resolveIosDetents(
        detents,
        environment: environment,
        profile: profile,
      );
    } on Object {
      return _result(IosSheetContentAdaptationStatus.resolutionFailed);
    }
    if (!resolved.any((detent) => detent.identifier == selectedDetent)) {
      return _result(IosSheetContentAdaptationStatus.missingSemanticSelection);
    }
    final resolvedContentDetent = resolved.where(
      (detent) => detent.identifier == contentDetent,
    );
    final expectedContentHeight = contentHeight > environment.maximumDetentHeight
        ? environment.maximumDetentHeight
        : contentHeight;
    if (resolvedContentDetent.length != 1 ||
        resolvedContentDetent.single.height != expectedContentHeight) {
      return _result(IosSheetContentAdaptationStatus.contentDetentMismatch);
    }

    _snapshot = IosSheetContentSnapshot(
      transaction: transaction,
      selectedDetent: _snapshot.selectedDetent,
      resolvedDetents: resolved,
      position: _snapshot.position,
      velocity: _snapshot.velocity,
      phase: phase,
      reasons: reasons,
      contentHeight: contentHeight,
    );
    return _result(IosSheetContentAdaptationStatus.applied);
  }

  IosSheetContentAdaptationResult _result(
    IosSheetContentAdaptationStatus status,
  ) => IosSheetContentAdaptationResult(status, _snapshot);
}
