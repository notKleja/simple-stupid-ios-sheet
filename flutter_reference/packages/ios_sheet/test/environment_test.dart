import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';
import 'helpers/environment_fixture.dart';

void main() {
  test('observed keyboard remains present when applied avoidance is zero', () {
    final env = environmentFixture();
    expect(env.observedKeyboardHeight, 300);
    expect(env.observedKeyboardFrame, const Rect.fromLTWH(0, 500, 400, 300));
    expect(env.appliedKeyboardAvoidance, 0);
    expect(
      env.keyboardHeight,
      0,
    ); // Source-compatible legacy applied-height API.
  });
  test(
    'environment equality includes observation and traits, not object identity',
    () {
      final first = environmentFixture();
      final second = environmentFixture();
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(environmentFixture(avoidance: 300)));
      expect(first.orientation, IosSheetOrientation.portrait);
      expect(first.stack.depth, 2);
      expect(first.textDirection, TextDirection.rtl);
    },
  );
  test('cache keys quantize physical geometry but retain policy changes', () {
    final env = environmentFixture();
    expect(env.cacheKey, environmentFixture(width: 400.01).cacheKey);
    expect(env, isNot(environmentFixture(width: 400.01)));
    expect(env.cacheKey, isNot(environmentFixture(width: 400.2).cacheKey));
    expect(env.cacheKey, isNot(environmentFixture(avoidance: 300).cacheKey));
  });
  test(
    'cache identity retains accessibility traits and unknown observations',
    () {
      expect(
        environmentFixture().cacheKey,
        isNot(environmentFixture(reduceMotion: false).cacheKey),
      );
      const unknown = IosSheetEnvironment(
        availableSize: Size(400, 800),
        maximumDetentHeight: 760,
      );
      const observedZero = IosSheetEnvironment(
        availableSize: Size(400, 800),
        maximumDetentHeight: 760,
        observedKeyboardHeight: 0,
      );
      expect(unknown.cacheKey, isNot(observedZero.cacheKey));
    },
  );
  test(
    'layout maximum rebasing retains observations instead of replacing them',
    () {
      final env = environmentFixture().withMaximumDetentHeight(700);
      expect(env.maximumDetentHeight, 700);
      expect(env.observedKeyboardHeight, 300);
      expect(env.appliedKeyboardAvoidance, 0);
      expect(env.contentHeight, 420);
      expect(env.textScale, 1.3);
      expect(env.contentSizeCategory, 'synthetic.category');
      expect(env.reduceMotion, isTrue);
      expect(env.platformBrightness, Brightness.dark);
      expect(env.locale, const Locale('ar', 'SA'));
      expect(env.stack.depth, 2);
    },
  );
}
