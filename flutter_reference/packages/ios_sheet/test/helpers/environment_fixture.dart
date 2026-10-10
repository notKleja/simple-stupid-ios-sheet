import 'package:flutter/widgets.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

/// Literal synthetic observations; these are not native profile constants.
IosSheetEnvironment environmentFixture({
  double width = 400,
  double avoidance = 0,
  bool reduceMotion = true,
}) => IosSheetEnvironment(
  availableSize: Size(width, 800),
  maximumDetentHeight: 760,
  safeArea: const EdgeInsets.only(top: 40, bottom: 30),
  displayScale: 3,
  observedKeyboardFrame: const Rect.fromLTWH(0, 500, 400, 300),
  observedKeyboardHeight: 300,
  appliedKeyboardAvoidance: avoidance,
  orientation: IosSheetOrientation.portrait,
  horizontalSizeClass: IosSheetSizeClass.compact,
  verticalSizeClass: IosSheetSizeClass.regular,
  contentHeight: 420,
  textScale: 1.3,
  contentSizeCategory: 'synthetic.category',
  reduceMotion: reduceMotion,
  platformBrightness: Brightness.dark,
  locale: const Locale('ar', 'SA'),
  textDirection: TextDirection.rtl,
  stack: const IosSheetStackContext(
    depth: 2,
    isTopmost: true,
    parentIdentifier: 'synthetic.parent',
  ),
);
