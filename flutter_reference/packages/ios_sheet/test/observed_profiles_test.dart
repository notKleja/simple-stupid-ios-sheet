import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  const base = IosSheetEnvironment(
    availableSize: Size(402, 874),
    maximumDetentHeight: 812,
    safeArea: EdgeInsets.only(top: 62, bottom: 34),
    displayScale: 3,
  );
  test('named observed iOS 26 profile matches legacy resolver', () {
    final named = observedIos26Page402x874Profile();
    // ignore: deprecated_member_use_from_same_package
    final legacy = observedPage402x874Profile(26);
    expect(named.majorVersion, 26);
    expect(named.evidence, legacy.evidence);
    expect(named.maximumDetentHeight(base), legacy.maximumDetentHeight(base));
    expect(named.mediumHeight(base), legacy.mediumHeight(base));
    expect(named.isMeasured, isFalse);
  });

  test('legacy observed resolver still rejects unsupported versions', () {
    for (final version in [25, 28]) {
      // ignore: deprecated_member_use_from_same_package
      expect(() => observedPage402x874Profile(version), throwsUnsupportedError);
    }
  });

  for (final version in [26, 27]) {
    test(
      'iOS $version qualified medium and large reproduce native resting frames',
      () {
        // ignore: deprecated_member_use_from_same_package
        final profile = observedPage402x874Profile(version);
        final maximum = profile.maximumDetentHeight(base);
        expect(maximum, 778);
        final env = IosSheetEnvironment(
          availableSize: base.availableSize,
          maximumDetentHeight: maximum,
          safeArea: base.safeArea,
          displayScale: 3,
        );
        final medium = profile.mediumHeight(env);
        expect(medium, closeTo(435.68, .000001));
        final visible = profile.detentToVisibleHeight(medium, env);
        final geometry = profile.geometry(
          IosSheetGeometryContext(
            environment: env,
            visibleHeight: visible,
            progress: visible / 812,
          ),
        );
        expect(visible * geometry.scale, closeTo(450.9734660033168, .000001));
        expect((402 - 402 * geometry.scale) / 2, closeTo(8, .000001));
        expect(geometry.bottomInset, closeTo(8, .000001));
        final large = profile.geometry(
          IosSheetGeometryContext(
            environment: env,
            visibleHeight: 812,
            progress: 1,
          ),
        );
        expect(large.scale, 1);
        expect(large.bottomInset, 0);
        expect(profile.isMeasured, isFalse); // Full parity is still unverified.
      },
    );
  }

  test(
    'qualified profile rejects unsupported geometries rather than extrapolating',
    () {
      final profile = observedIos26Page402x874Profile();
      expect(
        () => profile.maximumDetentHeight(
          const IosSheetEnvironment(
            availableSize: Size(390, 844),
            maximumDetentHeight: 800,
          ),
        ),
        throwsUnsupportedError,
      );
    },
  );
}
