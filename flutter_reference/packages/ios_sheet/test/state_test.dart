import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';
import 'helpers/environment_fixture.dart';

void main() {
  test(
    'point-space state keeps logical geometry and points-per-second velocity',
    () {
      final capabilities = {'motion': IosSheetCapabilityStatus.fallback};
      final provenance = {'motion': 'synthetic fixture'};
      final state = IosSheetState(
        frame: const Rect.fromLTWH(8, 415, 386, 451),
        velocity: const Offset(0, -120),
        phase: IosSheetPhase.snapping,
        selectedDetent: 'medium',
        targetDetent: 'large',
        restingDetent: null,
        gesture: IosSheetGestureState.none,
        sheetDragging: false,
        scroll: const IosSheetScrollObservation(),
        environment: environmentFixture(),
        capabilities: capabilities,
        provenance: provenance,
      );
      capabilities['motion'] = IosSheetCapabilityStatus.accepted;
      provenance['motion'] = 'mutated caller data';
      expect(state.position, const Offset(8, 415));
      expect(state.velocity, const Offset(0, -120));
      expect(state.frame.size, const Size(386, 451));
      expect(state.capabilities['motion'], IosSheetCapabilityStatus.fallback);
      expect(state.provenance['motion'], 'synthetic fixture');
      expect(() => state.capabilities.clear(), throwsUnsupportedError);
      expect(state.scroll.offset, isNull);
    },
  );
}
