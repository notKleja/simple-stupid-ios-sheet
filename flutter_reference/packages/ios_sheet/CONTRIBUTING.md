# Contributing

The public package has one native-reference scope: iOS 26. Its default profile
is an explicitly unmeasured fallback. Preserve provenance, qualification checks,
deprecated compatibility paths, and evidence labels when changing behavior.
Do not describe host tests or a Simulator launch as accepted native parity.

Clone the full repository, then run these checks from `flutter_reference` using
the verified Flutter 3.44.6 release and its bundled Dart 3.12.2. Workspace
resolution requires Dart 3.12.2 or later within Dart 3 because the candidate
declares `sdk: ^3.12.2`. The wrapper-only manifest's Dart 3.12.0 and Flutter
3.44.0 lower bounds have not been verified and do not satisfy the checkout's
workspace requirement by themselves.

```sh
flutter pub get --no-example
bash tool/check_format.sh
flutter analyze --fatal-infos --no-pub packages/ios_sheet_engine/lib packages/ios_sheet_engine/test packages/ios_sheet candidate packages/ios_sheet/example
flutter test --no-pub packages/ios_sheet_engine/test
flutter test --no-pub packages/ios_sheet/test
flutter test --no-pub candidate/test
flutter test --no-pub packages/ios_sheet/example/test
bash tool/verify_path_consumer.sh "$PWD/packages/ios_sheet"
cmp ../LICENSE packages/ios_sheet/LICENSE
```

These are host dependency, static, documentation, and Flutter test checks. The
engine's standalone legacy example has a network Git dependency and is excluded
by `--no-example`; it is outside the workspace test/analysis scope. The shared
format check is also used by CI. It checks tracked wrapper/example/tool/test and
candidate Dart files, preserving engine formatting and exactly four documented
existing drift exemptions in `tool/check_format.sh`. Analysis and tests still
cover those files.

Generate the API-check inputs and run the compatibility gate from
`flutter_reference`:

```sh
cd packages/ios_sheet
dart doc --output=build/api_docs .
cd ../ios_sheet_engine
dart doc --output=build/api_docs .
cd ../ios_sheet
dart tool/check_api_surface.dart \
  build/api_docs/index.json \
  ../ios_sheet_engine/build/api_docs/index.json \
  build/api_docs/simple_stupid_ios_sheet/StupidSimpleIosSheetRoute-class.html \
  tool/api_surface.json
cd ../..
```

Each dartdoc command must exit successfully and report
`Found 0 warnings and 0 errors.` Fix any documentation warning or error before
running the API checker; CI enforces the same requirement. The checker must
report no removals or changes. Additions are reported for review. Baseline
updates require explicit review of the API diff and compatibility checks;
do not refresh the baseline automatically to make a failure pass.

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
