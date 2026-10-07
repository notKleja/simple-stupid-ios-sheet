import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/src/content_adaptation.dart';
import '../lib/src/detents.dart';
import '../lib/src/profile.dart';
import '../lib/src/state.dart';

void main() {
  const environment = IosSheetEnvironment(
    availableSize: Size(400, 800),
    maximumDetentHeight: 760,
  );

  IosSheetContentSnapshot snapshot({
    String selectedDetent = 'content',
    int transaction = 1,
    IosSheetPhase phase = IosSheetPhase.presented,
  }) => IosSheetContentSnapshot(
    transaction: transaction,
    selectedDetent: selectedDetent,
    resolvedDetents: resolveIosDetents(
      [IosSheetDetent.height('content', 300), IosSheetDetent.large],
      environment: environment,
      profile: IosSheetProfile.ios26,
    ),
    position: const Offset(17, 29),
    velocity: const Offset(3, -4),
    phase: phase,
    reasons: const {IosSheetContentInvalidationReason.content},
  );

  test('failed resolution leaves the prior snapshot intact atomically', () {
    final adaptation = IosSheetContentAdaptation(snapshot: snapshot());
    final before = adaptation.snapshot;

    final result = adaptation.invalidate(
      transaction: 2,
      selectedDetent: 'content',
      contentHeight: 320,
      contentDetent: 'content',
      detents: [IosSheetDetent.height('content', 0)],
      environment: environment,
      profile: IosSheetProfile.ios26,
      phase: IosSheetPhase.snapping,
      reasons: const {IosSheetContentInvalidationReason.content},
    );

    expect(result.status, IosSheetContentAdaptationStatus.resolutionFailed);
    expect(result.snapshot, same(before));
    expect(adaptation.snapshot, same(before));
  });

  test('successful reorder preserves semantic selected detent', () {
    final adaptation = IosSheetContentAdaptation(snapshot: snapshot());

    final result = adaptation.invalidate(
      transaction: 2,
      selectedDetent: 'content',
      contentHeight: 600,
      contentDetent: 'content',
      detents: [IosSheetDetent.height('content', 600), IosSheetDetent.height('other', 300)],
      environment: environment,
      profile: IosSheetProfile.ios26,
      phase: IosSheetPhase.snapping,
      reasons: const {IosSheetContentInvalidationReason.content},
    );

    expect(result.status, IosSheetContentAdaptationStatus.applied);
    expect(result.snapshot.selectedDetent, 'content');
    expect(result.snapshot.resolvedDetents.map((detent) => detent.identifier), ['other', 'content']);
    expect(result.snapshot.position, const Offset(17, 29));
    expect(result.snapshot.velocity, const Offset(3, -4));
  });

  for (final (:phase, :reason) in [
    (phase: IosSheetPhase.presented, reason: IosSheetContentInvalidationReason.content),
    (phase: IosSheetPhase.dragging, reason: IosSheetContentInvalidationReason.dynamicType),
    (phase: IosSheetPhase.snapping, reason: IosSheetContentInvalidationReason.content),
    (phase: IosSheetPhase.snapping, reason: IosSheetContentInvalidationReason.keyboard),
  ]) {
    test('preserves $phase with $reason invalidation reason', () {
      final adaptation = IosSheetContentAdaptation(
        snapshot: snapshot(phase: phase),
      );

      final result = adaptation.invalidate(
        transaction: 2,
        selectedDetent: 'content',
        contentHeight: 320,
        contentDetent: 'content',
        detents: [IosSheetDetent.height('content', 320), IosSheetDetent.large],
        environment: environment,
        profile: IosSheetProfile.ios26,
        phase: phase,
        reasons: {reason},
      );

      expect(result.status, IosSheetContentAdaptationStatus.applied);
      expect(result.snapshot.phase, phase);
      expect(result.snapshot.reasons, {reason});
    });
  }

  test('invalid content size leaves snapshot intact with explicit status', () {
    final adaptation = IosSheetContentAdaptation(snapshot: snapshot());
    final before = adaptation.snapshot;

    for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
      final result = adaptation.invalidate(
        transaction: 2,
        selectedDetent: 'content',
        contentHeight: invalid,
        contentDetent: 'content',
        detents: [IosSheetDetent.height('content', 320)],
        environment: environment,
        profile: IosSheetProfile.ios26,
        phase: IosSheetPhase.presented,
        reasons: const {IosSheetContentInvalidationReason.content},
      );
      expect(result.status, IosSheetContentAdaptationStatus.invalidContentHeight);
      expect(result.snapshot, same(before));
    }
  });

  test('missing selection and stale transactions leave snapshot intact', () {
    final adaptation = IosSheetContentAdaptation(
      snapshot: snapshot(selectedDetent: 'absent', transaction: 4),
    );
    final before = adaptation.snapshot;

    final missing = adaptation.invalidate(
      transaction: 5,
      selectedDetent: 'absent',
      contentHeight: 320,
      contentDetent: 'content',
      detents: [IosSheetDetent.height('content', 320)],
      environment: environment,
      profile: IosSheetProfile.ios26,
      phase: IosSheetPhase.presented,
      reasons: const {IosSheetContentInvalidationReason.content},
    );
    final stale = adaptation.invalidate(
      transaction: 4,
      selectedDetent: 'absent',
      contentHeight: 320,
      contentDetent: 'content',
      detents: [IosSheetDetent.height('content', 320)],
      environment: environment,
      profile: IosSheetProfile.ios26,
      phase: IosSheetPhase.presented,
      reasons: const {IosSheetContentInvalidationReason.content},
    );

    expect(missing.status, IosSheetContentAdaptationStatus.missingSemanticSelection);
    expect(stale.status, IosSheetContentAdaptationStatus.staleTransaction);
    expect(adaptation.snapshot, same(before));
  });

  test('rejects a caller claim that switches semantic selection', () {
    final adaptation = IosSheetContentAdaptation(snapshot: snapshot());
    final before = adaptation.snapshot;

    final result = adaptation.invalidate(
      transaction: 2,
      selectedDetent: 'large',
      contentHeight: 320,
      contentDetent: 'content',
      detents: [IosSheetDetent.height('content', 320), IosSheetDetent.large],
      environment: environment,
      profile: IosSheetProfile.ios26,
      phase: IosSheetPhase.snapping,
      reasons: const {IosSheetContentInvalidationReason.content},
    );

    expect(
      result.status,
      IosSheetContentAdaptationStatus.semanticSelectionMismatch,
    );
    expect(result.snapshot, same(before));
  });

  test('rejects content height that does not match its named detent', () {
    final adaptation = IosSheetContentAdaptation(snapshot: snapshot());
    final before = adaptation.snapshot;

    final result = adaptation.invalidate(
      transaction: 2,
      selectedDetent: 'content',
      contentHeight: 600,
      contentDetent: 'content',
      detents: [IosSheetDetent.height('content', 300), IosSheetDetent.large],
      environment: environment,
      profile: IosSheetProfile.ios26,
      phase: IosSheetPhase.presented,
      reasons: const {IosSheetContentInvalidationReason.content},
    );

    expect(result.status, IosSheetContentAdaptationStatus.contentDetentMismatch);
    expect(result.snapshot, same(before));
  });

  test('binds content height while a different semantic detent stays selected', () {
    final adaptation = IosSheetContentAdaptation(
      snapshot: snapshot(selectedDetent: 'large'),
    );

    final result = adaptation.invalidate(
      transaction: 2,
      selectedDetent: 'large',
      contentHeight: 600,
      contentDetent: 'content',
      detents: [IosSheetDetent.height('content', 600), IosSheetDetent.large],
      environment: environment,
      profile: IosSheetProfile.ios26,
      phase: IosSheetPhase.snapping,
      reasons: const {IosSheetContentInvalidationReason.dynamicType},
    );

    expect(result.status, IosSheetContentAdaptationStatus.applied);
    expect(result.snapshot.selectedDetent, 'large');
    expect(
      result.snapshot.resolvedDetents
          .singleWhere((detent) => detent.identifier == 'content')
          .height,
      600,
    );
  });
}
