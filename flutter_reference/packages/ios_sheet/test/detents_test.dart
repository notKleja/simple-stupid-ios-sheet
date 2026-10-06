import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  const environment = IosSheetEnvironment(
    availableSize: Size(400, 800),
    maximumDetentHeight: 760,
    safeArea: EdgeInsets.only(top: 40, bottom: 20),
  );

  test('height and fraction detents resolve against maximum, not screen', () {
    final resolved = resolveIosDetents(
      [
        IosSheetDetent.height('short', 320),
        IosSheetDetent.fraction('fraction', .75),
        IosSheetDetent.large,
      ],
      environment: environment,
      profile: IosSheetProfile.ios26,
    );
    expect(resolved.map((e) => e.height), [320, 570, 760]);
    expect(resolved.map((e) => e.relativeExtent), [320 / 760, .75, 1]);
  });

  test('resolver sorts detents while preserving identifiers', () {
    final resolved = resolveIosDetents(
      [IosSheetDetent.large, IosSheetDetent.height('low', 200)],
      environment: environment,
      profile: IosSheetProfile.ios26,
    );
    expect(resolved.map((e) => e.identifier), ['low', 'large']);
  });

  test('duplicate identifiers and invalid custom values fail explicitly', () {
    expect(
      () => resolveIosDetents(
        [IosSheetDetent.large, IosSheetDetent.height('large', 200)],
        environment: environment,
        profile: IosSheetProfile.ios26,
      ),
      throwsArgumentError,
    );
    for (final height in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => resolveIosDetents(
          [IosSheetDetent.custom('invalid', (_) => height)],
          environment: environment,
          profile: IosSheetProfile.ios26,
        ),
        throwsArgumentError,
      );
    }
  });

  test('custom heights clamp to maximum and keep semantic identity', () {
    final resolved = resolveIosDetents(
      [IosSheetDetent.custom('oversized', (_) => 900)],
      environment: environment,
      profile: IosSheetProfile.ios26,
    );
    expect(resolved.single.height, 760);
    expect(resolved.single.identifier, 'oversized');
  });

  test('native medium resolution comes from the selected OS profile', () {
    final p26 = IosSheetProfile.ios26.copyWith(
      mediumHeight: (_) => 370,
      evidence: {'medium': 'fixture:26'},
    );
    final p27 = IosSheetProfile.ios27.copyWith(
      mediumHeight: (_) => 390,
      evidence: {'medium': 'fixture:27'},
    );
    double height(IosSheetProfile profile) => resolveIosDetents(
      [IosSheetDetent.medium],
      environment: environment,
      profile: profile,
    ).single.height;
    expect(height(p26), 370);
    expect(height(p27), 390);
    expect(IosSheetProfile.ios26.isMeasured, isFalse);
    expect(IosSheetProfile.ios27.isMeasured, isFalse);
  });

  test('unsupported OS does not silently inherit a newer profile', () {
    expect(() => IosSheetProfile.forMajorVersion(25), throwsUnsupportedError);
    expect(() => IosSheetProfile.forMajorVersion(28), throwsUnsupportedError);
  });
}
