# Contributing

The public package has one native-reference scope: iOS 26. Its default profile
is an explicitly unmeasured fallback. Preserve provenance, qualification checks,
deprecated compatibility paths, and evidence labels when changing behavior.
Do not describe host tests or a Simulator launch as accepted native parity.

Clone the full repository, then run these checks from `flutter_reference` with
Flutter 3.44.0 or later and Dart 3.12.0 or later:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed packages/ios_sheet/lib packages/ios_sheet/test packages/ios_sheet/example/lib packages/ios_sheet/example/test
flutter analyze --fatal-infos packages/ios_sheet_engine/lib packages/ios_sheet_engine/test packages/ios_sheet candidate packages/ios_sheet/example
flutter test --no-pub packages/ios_sheet_engine/test
flutter test --no-pub packages/ios_sheet
flutter test --no-pub candidate/test
flutter test --no-pub packages/ios_sheet/example/test
dart doc --dry-run packages/ios_sheet
dart doc --dry-run packages/ios_sheet_engine
bash tool/verify_path_consumer.sh "$PWD/packages/ios_sheet"
cd ..
cmp LICENSE flutter_reference/packages/ios_sheet/LICENSE
```

These are host dependency, static, documentation, and Flutter test checks. The
engine's standalone legacy example has a network Git dependency and is outside
the workspace test/analysis scope. Pub may still resolve it while traversing
examples. Do not refresh the public API baseline automatically; review additions
and compatibility changes against the API gate before accepting a new baseline.

Run the public example on an iOS Simulator with `flutter run -t lib/main.dart
-d <simulator-id>` from `packages/ios_sheet/example` after generating local
platform scaffolding if needed. This checks Flutter runtime behavior on that
Simulator; it does not measure UIKit geometry or certify native parity.

For native evidence, follow the repository
[measurement documentation](../../../measurement/README.md) and
[master state](../../../spec/MASTER_STATE.md). Record the OS/build, device or
Simulator identity, environment, scenario, artifact hashes, and repeated native
observations. Physical-device pacing/gestures require physical-device evidence;
Simulator or synthetic results cannot substitute for it. A qualified research
profile must fail outside its measured environment. Recover construction/math
and coordinate composition before promoting a native model.

Keep patches narrow, add a failing behavior test before implementing a feature,
and retain upstream tests and license attribution. Update changelog, docs, and
dependent workspace version constraints together. Use a short Conventional
Commit subject under 60 characters, without attribution trailers. See
[fork provenance](../../../docs/FORK_PROVENANCE.md) before syncing the engine.
