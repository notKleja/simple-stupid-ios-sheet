# Opaque iOS candidate and playground

This app uses only `StupidSimpleIosSheetRoute`. It supports a manual playground
and an automatic ten-trial counterpart to `native.medium_large.programmatic`.
The replay commands occur1.5s,3s,4.5s after presentation request; actual receipt
events are recorded. Completion is engine status, not physical native settling.

From this directory:

```sh
flutter pub get --no-example
flutter test --no-pub
flutter build ios --simulator --config-only --no-codesign --no-pub \
  --dart-define=SHEET_AUTORUN=true --dart-define=SHEET_TRIALS=10 \
  --dart-define=SHEET_PROFILE_MAJOR=27
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator \
  -destination 'id=<verified-simulator-UDID>' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO -derivedDataPath ../../work/CandidateDerivedData build
xcrun simctl install <verified-simulator-UDID> \
  ../../work/CandidateDerivedData/Build/Products/Debug-iphonesimulator/Runner.app
xcrun simctl launch <verified-simulator-UDID> dev.sheetreference.iosSheetCandidate
```

Set profile major26 for26runs; set autorunfalse for the interactive playground.
The installed `lipo` on this Mac rejects a multi-architecture verification even
though the Flutter framework contains arm64 andx86_64. An arm64-only destination
build is verified. The generated project targets iOS26minimum.

Runtime JSONL files are saved in the app's Documents directory. Obtain its
container with `xcrun simctl get_app_container <UDID> dev.sheetreference.iosSheetCandidate data`.
Metadata comes from the native host, including actual screen geometry, scale,
safe area, size classes, OS, model and display's maximum refresh rate. Simulator
build uses `SIMULATOR_RUNTIME_BUILD_VERSION`; a host-kernel build is never used.
The recorder uses a monotonic microsecond clock converted to nanoseconds.

Runtime traces and clocks are separate from widget-test proof. Shape, barrier,
motion and gesture constants still have explicit fallback/provisional status.
Qualified native geometry activates only for the tested402x874@3x environment,
the reference detents, keyboard hidden and calibration content. Other cases
use independent unmeasured26/27 profiles.

The manual controls change profile, detents, content, modality, drag/dismissal,
content interaction, conventional grabber and debug overlay. Buttons in the
sheet perform semantic selection and explicit dismissal. Grabber styling is a
conventional opaque fallback. Native form/page adaptivity, placement, stacking,
Reduce Motion and keyboard synchronization are outstanding API work.
