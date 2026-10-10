# iOS 26 Package Developer Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a source-compatible, iOS-26-scoped Flutter package journey with a distinct local engine identity, a familiar presentation helper, reproducible compatibility gates, accurate docs, a runnable example, pinned CI, and no unsupported native-parity claims.

**Architecture:** Rename the locally extended transition engine so Pub cannot confuse it with the published upstream package, then prove external sibling-path resolution before documenting installation. Keep the existing advanced route and barrel compatible; add a thin `showIos26Sheet` facade and strict iOS 26 reference APIs while preserving deprecated iOS 27 behavior. Guard the surface with normalized dartdoc output plus compile fixtures, and validate each evidence layer separately.

**Tech Stack:** Flutter 3.44.6, Dart 3.12.2, Dart pub workspaces/path dependencies, Flutter widget tests, dartdoc `index.json`, GitHub Actions, Xcode 27.0, iOS 26 Simulator.

**Spec:** `docs/superpowers/specs/2026-10-11-ios26-package-dx-design.md`

## Global Constraints

- Work only on `feat/ios26-package-dx`, based on `feat/synchronized-demo-video` at `db18f75`.
- iOS 26 is the sole developer-facing native-reference scope; `IosSheetProfile.ios26` remains an unmeasured fallback.
- Preserve existing wrapper exports, constructors, defaults, callbacks, exception classes, detent semantics, trace formats, and iOS 27 compatibility behavior.
- Rename the local engine to `ios_sheet_engine` version `1.0.0-dev.4+fork.1`; keep upstream MIT text and archive provenance unchanged.
- Keep `simple_stupid_ios_sheet` unpublished at `0.1.0-dev.2`; do not publish or create a binary release.
- Do not add extra entrypoints, native behavior, Liquid Glass, runtime dependencies, telemetry, or broad formatting.
- Keep `trajectoryModel` and `onUnderlyingHitObserved` advanced-route-only.
- Use short one-line Conventional Commits under 60 characters without attribution trailers.
- Run `flutter analyze --fatal-infos`; suppress only exact intentional deprecated compatibility uses.
- Treat host tests, builds, Simulator launches, traces, and physical-device evidence as separate proof layers.

## Review Focus

- An external app resolves the wrapper and renamed sibling engine without selecting pub.dev's incompatible upstream package; Task 2 owns this test.
- Deprecated iOS 27 APIs remain compatible while wrapper and candidate analysis pass with fatal infos; Task 4 owns this test.
- `showIos26Sheet` preserves typed results, navigator selection, route settings, and synchronous invalid-detent errors; Task 5 owns parity tests.
- API normalization keeps wrapper-declared and engine-inherited route members but excludes Flutter-SDK-only inheritance; Task 3 owns synthetic and real-index tests.
- README/example state that iOS 26 is scope while the default is unmeasured, and reserve advanced seams for direct-route use; Task 7 owns this audit.

---

### Task 1: Rename the forked engine mechanically

**Files:**
- Move: `flutter_reference/packages/stupid_simple_sheet/` to `flutter_reference/packages/ios_sheet_engine/`
- Move: `flutter_reference/packages/ios_sheet_engine/lib/stupid_simple_sheet.dart` to `flutter_reference/packages/ios_sheet_engine/lib/ios_sheet_engine.dart`
- Modify: `flutter_reference/packages/ios_sheet_engine/pubspec.yaml`
- Modify: `flutter_reference/pubspec.yaml`
- Modify: `flutter_reference/packages/ios_sheet/pubspec.yaml`
- Modify: wrapper imports in `lib/simple_stupid_ios_sheet.dart` and `lib/src/{motion,profile,route}.dart`
- Modify: every engine `lib/`, `test/`, and `example/` import with the old package URI
- Modify: `flutter_reference/UPSTREAM.md`, `flutter_reference/SUMMARY.md`

**Interfaces:**
- Consumes: local `stupid_simple_sheet 1.0.0-dev.4`.
- Produces: `ios_sheet_engine 1.0.0-dev.4+fork.1`, barrel `package:ios_sheet_engine/ios_sheet_engine.dart`, and wrapper path dependency `../ios_sheet_engine`.

- [ ] **Step 1: Record the mechanical baseline**

Run:

```bash
cd flutter_reference
flutter pub get
flutter analyze --fatal-infos packages/stupid_simple_sheet packages/ios_sheet
flutter test --no-pub packages/stupid_simple_sheet/test
flutter test --no-pub packages/ios_sheet
git grep -n 'package:stupid_simple_sheet/' -- packages/stupid_simple_sheet packages/ios_sheet
```

Expected: analysis passes, engine tests pass, wrapper reports 105 passing tests, and grep inventories every import to rewrite.

- [ ] **Step 2: Move the directory and barrel**

```bash
git mv flutter_reference/packages/stupid_simple_sheet flutter_reference/packages/ios_sheet_engine
git mv flutter_reference/packages/ios_sheet_engine/lib/stupid_simple_sheet.dart flutter_reference/packages/ios_sheet_engine/lib/ios_sheet_engine.dart
```

- [ ] **Step 3: Change only identity and wiring**

Set the engine manifest to:

```yaml
name: ios_sheet_engine
version: 1.0.0-dev.4+fork.1
```

Set the wrapper dependency to:

```yaml
ios_sheet_engine:
  path: ../ios_sheet_engine
```

Change the workspace member, every active import prefix, and the wrapper's selective re-export. Preserve the existing `show` list exactly.

- [ ] **Step 4: Update provenance paths only**

Keep the upstream package name, archive version, URL, SHA-256, publication time, copyright, and import evidence in `UPSTREAM.md`. Add the new fork identity/path. Update active path references in `SUMMARY.md`; leave historical specs/plans unchanged.

- [ ] **Step 5: Prove the rename is mechanical**

```bash
cd flutter_reference
flutter pub get
flutter analyze --fatal-infos packages/ios_sheet_engine packages/ios_sheet
flutter test --no-pub packages/ios_sheet_engine/test
flutter test --no-pub packages/ios_sheet
git grep -n 'package:stupid_simple_sheet/' -- .
git diff -M --stat c2defec -- packages
```

Expected: grep has no matches, baseline suites pass, and the diff is dominated by renames/import substitutions.

- [ ] **Step 6: Commit the mechanical change alone**

```bash
git add flutter_reference
git commit -m "refactor: rename engine to ios_sheet_engine"
```

---

### Task 2: Prove and fix external path resolution

**Files:**
- Create: `flutter_reference/tool/verify_path_consumer.sh`
- Conditionally modify: wrapper/engine/root/candidate pubspec files

**Interfaces:**
- Consumes: renamed engine and wrapper path dependency.
- Produces: reproducible external-consumer verification and one proven resolution model.

- [ ] **Step 1: Create the external-consumer verifier**

The strict shell script accepts an absolute wrapper path, creates a `mktemp -d` Flutter app, adds a path dependency, and writes this smoke test before running `flutter pub get`, `flutter analyze --fatal-infos`, and `flutter test`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  test('external consumer resolves the package surface', () {
    expect(IosSheetProfile.ios26.majorVersion, 26);
    expect(IosSheetDetent.large.identifier, 'large');
  });
}
```

- [ ] **Step 2: Run it outside the workspace**

```bash
bash flutter_reference/tool/verify_path_consumer.sh \
  "$PWD/flutter_reference/packages/ios_sheet"
```

Expected: either all checks pass or Pub reports a specific workspace-resolution failure. Record the actual output.

- [ ] **Step 3: Apply the conditional resolution fix**

Only if `resolution: workspace` causes the observed failure:

1. Remove it from wrapper and engine.
2. Remove those members from the root workspace list if Pub requires all members to opt in.
3. Give the candidate an explicit `path: ../packages/ios_sheet` dependency.
4. Retain the wrapper's engine path dependency.
5. Rerun repository and external checks.

If the first external test passes, retain the workspace metadata unchanged.

- [ ] **Step 4: Verify both boundaries**

```bash
cd flutter_reference
flutter pub get
flutter analyze --fatal-infos packages/ios_sheet_engine packages/ios_sheet candidate
flutter test --no-pub packages/ios_sheet_engine/test
flutter test --no-pub packages/ios_sheet
flutter test --no-pub candidate/test
cd ..
bash flutter_reference/tool/verify_path_consumer.sh \
  "$PWD/flutter_reference/packages/ios_sheet"
```

- [ ] **Step 5: Commit only tracked changes**

Use `fix: support external path consumers` if resolution metadata changed. If it did not, stage the verifier with Task 3 instead of creating an empty commit.

---

### Task 3: Add the public API surface gate

**Files:**
- Create: `flutter_reference/packages/ios_sheet/tool/api_surface.dart`
- Create: `flutter_reference/packages/ios_sheet/tool/update_api_surface.dart`
- Create: `flutter_reference/packages/ios_sheet/tool/check_api_surface.dart`
- Create: `flutter_reference/packages/ios_sheet/tool/api_surface.json`
- Create: `flutter_reference/packages/ios_sheet/test/api_surface_tool_test.dart`
- Create: `flutter_reference/packages/ios_sheet/test/api_compatibility_compile_test.dart`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: wrapper/engine dartdoc indexes and wrapper route class HTML.
- Produces: `normalizeApiSurface`, deterministic JSON, update/check CLIs, and compile fixtures.

- [ ] **Step 1: Write failing normalization tests**

Use synthetic index and HTML fixtures:

```dart
test('keeps declared and engine-inherited route members only', () {
  final symbols = normalizeApiSurface(
    wrapperIndex: wrapperFixture,
    engineIndex: engineFixture,
    routeHtml: routeHtmlFixture,
  );
  expect(symbols.map((e) => e.qualifiedName), containsAll([
    'simple_stupid_ios_sheet.IosSheetProfile',
    'simple_stupid_ios_sheet.StupidSimpleIosSheetRoute.profile',
    'simple_stupid_ios_sheet.StupidSimpleIosSheetRoute.animateToRelative',
  ]));
  expect(
    symbols.map((e) => e.qualifiedName),
    isNot(contains(
      'simple_stupid_ios_sheet.StupidSimpleIosSheetRoute.popDisposition',
    )),
  );
});

test('serializes stable fields only in sorted order', () {
  final output = encodeApiSurface(unsortedSymbols);
  expect(output, contains('"qualifiedName"'));
  expect(output, isNot(contains('href')));
  expect(output, isNot(contains('overriddenDepth')));
});
```

- [ ] **Step 2: Run the tests and verify missing-tool failure**

```bash
cd flutter_reference
flutter test packages/ios_sheet/test/api_surface_tool_test.dart
```

- [ ] **Step 3: Implement deterministic normalization**

```dart
final class ApiSymbol implements Comparable<ApiSymbol> {
  const ApiSymbol({
    required this.qualifiedName,
    required this.kind,
    required this.enclosingOwner,
  });

  final String qualifiedName;
  final int kind;
  final String? enclosingOwner;
}

List<ApiSymbol> normalizeApiSurface({
  required List<Object?> wrapperIndex,
  required List<Object?> engineIndex,
  required String routeHtml,
}) {
  const engineOwners = {
    'StupidSimpleSheetTransitionMixin',
    'StupidSimpleSheetController',
  };
  final engineNames = engineIndex
      .whereType<Map<String, Object?>>()
      .where((entry) {
        final owner = entry['enclosedBy'] as Map<String, Object?>?;
        return engineOwners.contains(owner?['name']);
      })
      .map((entry) => entry['name']! as String)
      .toSet();
  final inheritedNames = RegExp(
    r'<dt id="([^"]+)" class="[^"]* inherited">',
  ).allMatches(routeHtml).map((match) => match.group(1)!).toSet();
  final symbols = <ApiSymbol>[];
  for (final entry in wrapperIndex.whereType<Map<String, Object?>>()) {
    final owner = entry['enclosedBy'] as Map<String, Object?>?;
    final ownerName = owner?['name'] as String?;
    final name = entry['name']! as String;
    if (ownerName == 'StupidSimpleIosSheetRoute' &&
        inheritedNames.contains(name) &&
        !engineNames.contains(name)) {
      continue;
    }
    symbols.add(ApiSymbol(
      qualifiedName: entry['qualifiedName']! as String,
      kind: entry['kind']! as int,
      enclosingOwner: ownerName,
    ));
  }
  return symbols..sort();
}
```

The implementation must:

1. Parse `class="... inherited"` IDs from route HTML.
2. Derive engine-owned names from entries enclosed by `StupidSimpleSheetTransitionMixin` or `StupidSimpleSheetController`.
3. Keep non-inherited wrapper route entries.
4. Keep inherited wrapper route entries only when engine-owned.
5. Exclude Flutter-route-only inherited entries.
6. Emit only qualified name, numeric kind, and owner, sorted deterministically.

- [ ] **Step 4: Implement update/check CLIs**

`update_api_surface.dart` accepts wrapper index, engine index, route HTML, and output path. `check_api_surface.dart` accepts those plus the baseline, fails on removals/kind-owner changes, and prints additions without failing.

- [ ] **Step 5: Add signature compile fixtures**

Compile every existing route named parameter, controller action/state access, selective engine re-export, and representative engine-inherited methods (`animateToRelative`, `overrideSnappingConfig`). Compile deprecated iOS 27 APIs under exact ignore comments. Do not assert native behavior.

- [ ] **Step 6: Prove the engine rename preserved wrapper API**

Extract `c2defec` with `git archive` into `mktemp -d`, resolve the full `flutter_reference` workspace, generate pre-rename wrapper/engine docs, and compare normalized output to post-rename docs. Expected: identical normalized surfaces before feature additions.

- [ ] **Step 7: Generate and check the baseline**

```bash
cd flutter_reference/packages/ios_sheet
dart doc --output=build/api_docs .
cd ../ios_sheet_engine
dart doc --output=build/api_docs .
cd ../ios_sheet
dart run tool/update_api_surface.dart \
  build/api_docs/index.json \
  ../ios_sheet_engine/build/api_docs/index.json \
  build/api_docs/simple_stupid_ios_sheet/StupidSimpleIosSheetRoute-class.html \
  tool/api_surface.json
dart run tool/check_api_surface.dart \
  build/api_docs/index.json \
  ../ios_sheet_engine/build/api_docs/index.json \
  build/api_docs/simple_stupid_ios_sheet/StupidSimpleIosSheetRoute-class.html \
  tool/api_surface.json
```

- [ ] **Step 8: Ignore generated docs narrowly and commit**

Ignore only package `doc/api/` and `build/api_docs/` trees; authored `doc/troubleshooting.md` must remain visible. Commit with `test: add API surface gate`, including the external verifier if Task 2 did not commit it.

---

### Task 4: Add strict iOS 26 reference APIs

**Files:**
- Modify: `flutter_reference/packages/ios_sheet/lib/src/profile.dart`
- Modify: `flutter_reference/packages/ios_sheet/lib/src/observed_profiles.dart`
- Modify: `flutter_reference/packages/ios_sheet/test/detents_test.dart`
- Modify: `flutter_reference/packages/ios_sheet/test/observed_profiles_test.dart`
- Modify: `flutter_reference/packages/ios_sheet/test/api_compatibility_compile_test.dart`

**Interfaces:**
- Produces: `iosSheetReferenceMajorVersion`, `supportedIosSheetReferenceMajorVersions`, `IosSheetProfile.forReferenceVersion(int)`, and `observedIos26Page402x874Profile()`.
- Preserves: deprecated iOS 27 field/resolver/observed function behavior.

- [ ] **Step 1: Write failing strict-scope tests**

```dart
test('iOS 26 is the only supported reference version', () {
  expect(iosSheetReferenceMajorVersion, 26);
  expect(supportedIosSheetReferenceMajorVersions, const {26});
  expect(
    IosSheetProfile.forReferenceVersion(26),
    same(IosSheetProfile.ios26),
  );
  expect(
    () => IosSheetProfile.forReferenceVersion(27),
    throwsA(isA<UnsupportedError>()),
  );
});

test('legacy iOS 27 profile remains compatible', () {
  // ignore: deprecated_member_use_from_same_package
  final legacy = IosSheetProfile.ios27;
  // ignore: deprecated_member_use_from_same_package
  expect(IosSheetProfile.forMajorVersion(27), same(legacy));
  expect(legacy.majorVersion, 27);
});

test('named observed iOS 26 profile matches legacy resolver', () {
  final named = observedIos26Page402x874Profile();
  // ignore: deprecated_member_use_from_same_package
  final legacy = observedPage402x874Profile(26);
  expect(named.majorVersion, legacy.majorVersion);
  expect(named.evidence, legacy.evidence);
});
```

- [ ] **Step 2: Verify the tests fail on missing APIs**

```bash
cd flutter_reference
flutter test packages/ios_sheet/test/detents_test.dart \
  packages/ios_sheet/test/observed_profiles_test.dart
```

- [ ] **Step 3: Implement private delegation**

Use this public shape:

```dart
const iosSheetReferenceMajorVersion = 26;
const supportedIosSheetReferenceMajorVersions = {26};

@Deprecated('iOS 27 is an unsupported legacy research fallback. Use ios26.')
static final ios27 = _ios27;

static IosSheetProfile forReferenceVersion(int version) {
  if (version == iosSheetReferenceMajorVersion) return ios26;
  throw UnsupportedError('Only iOS 26 is a supported sheet reference');
}

@Deprecated('Use forReferenceVersion for the supported iOS 26 reference.')
static IosSheetProfile forMajorVersion(int version) =>
    _profileForMajorVersion(version);
```

Private `_ios27` and `_profileForMajorVersion` preserve the old switch. Both observed public functions delegate to one private implementation so wrapper library code never invokes deprecated members.

- [ ] **Step 4: Fix the baseline dartdoc warning**

Replace `[fixed320, medium, large]` with code-formatted names. Require `dart doc --dry-run .` to report zero warnings.

- [ ] **Step 5: Verify fatal infos and full wrapper regression**

```bash
cd flutter_reference
flutter analyze --fatal-infos packages/ios_sheet
flutter test --no-pub packages/ios_sheet
```

Expected: previous 105 tests and new tests pass without wrapper-lib suppressions.

- [ ] **Step 6: Commit**

Commit with `feat: add iOS 26 reference APIs`.

---

### Task 5: Add the `showIos26Sheet` facade

**Files:**
- Create: `flutter_reference/packages/ios_sheet/lib/src/show_sheet.dart`
- Modify: `flutter_reference/packages/ios_sheet/lib/simple_stupid_ios_sheet.dart`
- Modify: `flutter_reference/packages/ios_sheet/lib/src/route.dart`
- Create: `flutter_reference/packages/ios_sheet/test/show_sheet_test.dart`

**Interfaces:**
- Produces: `Future<T?> showIos26Sheet<T>(...)` and optional route `barrierLabel`.
- Omits: `trajectoryModel` and `onUnderlyingHitObserved`, which remain direct-route-only.

- [ ] **Step 1: Write helper/direct-route parity tests**

Add independent widget tests for exact typed pop result, default nested navigator, requested root navigator, `RouteSettings` identity/arguments, detents/initial selection, callbacks, controller ownership, default/supplied barrier labels, and iOS 26 profile. Add this failure-mode test:

```dart
expect(
  () => showIos26Sheet<void>(
    context: context,
    initialDetentIdentifier: 'missing',
    builder: (_) => const SizedBox(),
  ),
  throwsArgumentError,
);
expect(observer.pushCount, 0);
```

- [ ] **Step 2: Run and verify missing-helper failure**

```bash
cd flutter_reference
flutter test packages/ios_sheet/test/show_sheet_test.dart
```

- [ ] **Step 3: Add optional route barrier label**

Store constructor input as `_barrierLabel` and preserve:

```dart
@override
String get barrierLabel => _barrierLabel ?? 'Dismiss sheet';
```

- [ ] **Step 4: Implement a non-async thin adapter**

Use the exact signature and forwarding shape below. Do not accept or forward the two advanced-only parameters.

```dart
Future<T?> showIos26Sheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
  List<IosSheetDetent> detents = const [IosSheetDetent.large],
  String? initialDetentIdentifier,
  String? largestUndimmedDetentIdentifier,
  IosSheetController? controller,
  IosSheetContentInteraction contentInteraction =
      IosSheetContentInteraction.resizes,
  IosSheetKeyboardPolicy keyboardPolicy = IosSheetKeyboardPolicy.resize,
  bool draggable = true,
  bool dismissible = true,
  bool interactiveDismissDisabled = false,
  Color backgroundColor = CupertinoColors.systemBackground,
  Color modalBarrierColor = const Color.fromRGBO(0, 0, 0, .2),
  String? barrierLabel,
  ValueChanged<String>? onSelectedDetentChanged,
  VoidCallback? onPresented,
  VoidCallback? onDismissed,
}) {
  final route = StupidSimpleIosSheetRoute<T>(
    child: Builder(builder: builder),
    profile: IosSheetProfile.ios26,
    detents: detents,
    initialDetentIdentifier: initialDetentIdentifier,
    largestUndimmedDetentIdentifier: largestUndimmedDetentIdentifier,
    controller: controller,
    contentInteraction: contentInteraction,
    keyboardPolicy: keyboardPolicy,
    draggable: draggable,
    dismissible: dismissible,
    interactiveDismissDisabled: interactiveDismissDisabled,
    backgroundColor: backgroundColor,
    modalBarrierColor: modalBarrierColor,
    barrierLabel: barrierLabel,
    onSelectedDetentChanged: onSelectedDetentChanged,
    onPresented: onPresented,
    onDismissed: onDismissed,
    settings: routeSettings,
  );
  return Navigator.of(context, rootNavigator: useRootNavigator).push(route);
}
```

- [ ] **Step 5: Verify helper parity and wrapper regression**

```bash
cd flutter_reference
flutter analyze --fatal-infos packages/ios_sheet
flutter test --no-pub packages/ios_sheet/test/show_sheet_test.dart
flutter test --no-pub packages/ios_sheet
```

- [ ] **Step 6: Commit**

Commit with `feat: add showIos26Sheet helper`.

---

### Task 6: Make the candidate surface iOS 26-only

**Files:**
- Modify: `flutter_reference/candidate/lib/main.dart`
- Modify: `flutter_reference/candidate/lib/synchronized_demo.dart`
- Modify: `flutter_reference/candidate/test/playground_test.dart`
- Modify: `flutter_reference/candidate/README.md`

**Interfaces:**
- Consumes: strict and named iOS 26 APIs from Task 4.
- Produces: visible iOS 26-only playground with one internal compatibility shim.

- [ ] **Step 1: Add the failing UI scope test**

```dart
testWidgets('shows iOS 26 as the only reference target', (tester) async {
  await tester.pumpWidget(const IosSheetCandidateApp());
  await tester.pumpAndSettle();
  expect(find.textContaining('iOS 26'), findsWidgets);
  expect(find.textContaining('iOS 27'), findsNothing);
  expect(find.byType(DropdownButton<int>), findsNothing);
});
```

- [ ] **Step 2: Run it and observe the current selector failure**

```bash
cd flutter_reference
flutter test candidate/test/playground_test.dart
```

- [ ] **Step 3: Default to 26 and isolate legacy replay**

Keep `SHEET_PROFILE_MAJOR` only for internal research and default it to 26. Remove the visible selector. Route selection through one private shim:

```dart
IosSheetProfile _candidateProfile({required bool qualified}) {
  if (_major == 26) {
    return qualified
        ? observedIos26Page402x874Profile()
        : IosSheetProfile.ios26;
  }
  // ignore: deprecated_member_use
  return qualified
      ? observedPage402x874Profile(_major)
      : IosSheetProfile.forMajorVersion(_major);
}
```

If the analyzer reports both deprecated expressions independently, put one targeted ignore directly above each expression rather than suppressing the file. Change synchronized demo to the zero-argument iOS 26 observed function. Keep trace `profile_major` format unchanged.

- [ ] **Step 4: Repair candidate documentation**

Remove iOS 27 from the primary command, call the candidate a research harness rather than the package example, and fix merged words including `occur1.5s`, `major26`, `autorunfalse`, `andx86_64`, `iOS26minimum`, and `tested402x874`.

- [ ] **Step 5: Verify fatal infos and candidate tests**

```bash
cd flutter_reference
flutter analyze --fatal-infos candidate
flutter test --no-pub candidate/test
```

- [ ] **Step 6: Commit**

Commit with `feat(candidate): default to iOS 26`.

---

### Task 7: Build the complete package developer journey

**Files:**
- Create: wrapper `README.md`, `CHANGELOG.md`, `LICENSE`, `CONTRIBUTING.md`
- Create: `flutter_reference/packages/ios_sheet/doc/troubleshooting.md`
- Create: wrapper `example/pubspec.yaml`, `example/lib/main.dart`, `example/test/app_test.dart`
- Create: `docs/FORK_PROVENANCE.md`
- Modify: wrapper/candidate manifests, engine README, root README, Flutter architecture, and notices if the path changed

**Interfaces:**
- Consumes: renamed engine, proven resolution, strict iOS 26 APIs, and helper.
- Produces: wrapper `0.1.0-dev.2`, runnable example, onboarding, troubleshooting, contribution guide, and provenance matrix.

- [ ] **Step 1: Write the failing example smoke test**

Pump `Ios26SheetExampleApp`, tap `Show iOS 26 sheet`, and assert that sheet content and medium/large controls appear with no iOS 27 copy. Run it and expect a compile failure before creating the app.

- [ ] **Step 2: Add the minimal public example**

```dart
await showIos26Sheet<void>(
  context: context,
  detents: const [IosSheetDetent.medium, IosSheetDetent.large],
  initialDetentIdentifier: 'medium',
  builder: (_) => const ExampleSheetContent(),
);
```

The example has no trace recorder, native metadata channel, profile selector, or Liquid Glass dependency.

- [ ] **Step 3: Put evidence truth on the README first screen**

Before installation, state:

```markdown
This package uses iOS 26 as its only native-reference scope.

Its default `IosSheetProfile.ios26` is an explicitly unmeasured fallback, not
a claim of complete observed or accepted native parity.
```

Then document clone/path installation, helper usage, direct route, controller ownership, support-status table, troubleshooting, example, provenance, and upstream attribution. State that the two omitted helper seams require direct route construction.

- [ ] **Step 4: Add exact license and release assets**

Copy root `LICENSE` byte-for-byte. Add `CHANGELOG.md` for `0.1.0-dev.2`. Bump the wrapper and candidate dependency together. Add repository, issue tracker, documentation, and topics while retaining `publish_to: none`.

- [ ] **Step 5: Add troubleshooting and contribution guides**

Cover detached/reused/covered controllers, invalid detents, pre-layout capture, fixed-surface interruption, qualified-profile rejection, explicit versus interactive dismissal, and synchronous helper validation. Contributor commands must distinguish host, Simulator, and physical/native parity evidence.

- [ ] **Step 6: Add provenance and engine fork banner**

Document upstream archive hash, tag/head corroboration, import commit, fork seams, engine identity, wrapper purpose, licenses, and sync risks. The engine README must not tell users to install published `stupid_simple_sheet` for fork-only seams.

- [ ] **Step 7: Verify assets and docs**

```bash
cmp LICENSE flutter_reference/packages/ios_sheet/LICENSE
cd flutter_reference
flutter pub get
flutter analyze --fatal-infos packages/ios_sheet candidate packages/ios_sheet/example
flutter test --no-pub packages/ios_sheet
flutter test --no-pub packages/ios_sheet/example/test
cd packages/ios_sheet
dart doc --dry-run .
```

Expected: licenses match, analysis/tests pass, dartdoc has zero warnings.

- [ ] **Step 8: Run publish diagnostics without publishing**

Run `dart pub publish --dry-run`. If `publish_to: none` prevents useful validation, copy wrapper and engine into a fresh temporary directory, remove only that field from the copy, and rerun. Record path-dependency hosting limitations; do not publish or loosen dependencies.

- [ ] **Step 9: Commit**

Commit with `docs: add iOS 26 package journey`.

---

### Task 8: Add pinned package-DX CI

**Files:**
- Create: `.github/workflows/package-dx.yml`
- Modify: `flutter_reference/tool/verify_path_consumer.sh` only for CI portability

**Interfaces:**
- Consumes: verification commands/tools from Tasks 1-7.
- Produces: pinned host-level CI with no native-parity claim.

- [ ] **Step 1: Add the pinned workflow**

Use `subosito/flutter-action` with Flutter `3.44.6`, channel `stable`, and cache enabled. Add a step that fails unless `dart --version` contains `3.12.2`.

- [ ] **Step 2: Encode separate evidence checks**

Run formatting, fatal-info analysis, engine tests, wrapper tests, candidate tests, example tests, dartdoc, API gate, license comparison, and external path consumer verification as separately named steps. Exclude the engine's non-workspace example with its network Git dependency. Do not call this workflow native parity.

- [ ] **Step 3: Validate every workflow command locally**

Run each shell command from the same working directory, then parse YAML:

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/package-dx.yml"); puts "valid"'
```

Expected: `valid` and every local command passes.

- [ ] **Step 4: Commit**

Commit with `ci: add pinned package DX checks`.

---

### Task 9: Regenerate the API baseline and run full verification

**Files:**
- Modify: `flutter_reference/packages/ios_sheet/tool/api_surface.json`
- Create locally only: ignored verification and Simulator artifacts

**Interfaces:**
- Consumes: final wrapper, engine, candidate, example, tooling, and CI commands.
- Produces: additions-only API diff, complete evidence, and one frozen review SHA.

- [ ] **Step 1: Regenerate the final API surface**

Generate wrapper and engine docs under `build/api_docs`, update the baseline, and inspect the diff. Expected additions are the iOS 26 constants/resolver, named observed profile, helper, and barrier-label exposure. No baseline symbol may disappear or change kind/owner. Specifically confirm that deprecating `ios27` preserves its API-gate kind; keep it as an annotated field rather than a getter if the kind would change.

- [ ] **Step 2: Run full host verification**

```bash
cd flutter_reference
flutter pub get
dart format --output=none --set-exit-if-changed \
  packages/ios_sheet/lib packages/ios_sheet/test packages/ios_sheet/tool \
  packages/ios_sheet/example/lib packages/ios_sheet/example/test \
  packages/ios_sheet_engine/lib packages/ios_sheet_engine/test \
  candidate/lib candidate/test
flutter analyze --fatal-infos packages/ios_sheet_engine packages/ios_sheet \
  packages/ios_sheet/example candidate
flutter test --no-pub packages/ios_sheet_engine/test
flutter test --no-pub packages/ios_sheet
flutter test --no-pub packages/ios_sheet/example/test
flutter test --no-pub candidate/test
bash tool/verify_path_consumer.sh "$PWD/packages/ios_sheet"
cmp ../LICENSE packages/ios_sheet/LICENSE
```

Generate dartdoc with zero warnings and run the API checker after these commands.

- [ ] **Step 3: Run iOS 26 Simulator smoke checks**

Build and launch the candidate in Debug and Release on an available iOS 26 Simulator. Verify launch, presentation, medium-to-large selection, explicit dismissal, and absence of a visible iOS 27 selector. Record runtime/build/device identity and do not present this as physical-device evidence.

- [ ] **Step 4: Refresh graph knowledge outside the checkout**

Copy the final checkout to a temporary directory and run `graphify --update` there. Review the report for missed relationships; do not stage graph churn into feature commits.

- [ ] **Step 5: Commit the final baseline if needed**

Commit only a changed API baseline with `test: refresh package API baseline`. Skip the commit if the baseline was already regenerated after the final public API change.

---

### Task 10: Run three independent reviews and deliver the stacked PR

**Files:**
- Review: `feat/synchronized-demo-video...feat/ios26-package-dx`
- Modify: only files required by reproduced material findings

**Interfaces:**
- Consumes: frozen verified review SHA.
- Produces: corrected branch, pushed commits, stacked PR, and the required engineering report.

- [ ] **Step 1: Dispatch three fresh read-only reviewers concurrently**

Reviewer A covers public API and behavioral compatibility. Reviewer B executes first-use, troubleshooting, contributor, and upgrade journeys. Reviewer C covers platform, dependency, security, licensing, and attribution. Each returns exact path/line evidence, severity, reproduction, and a must-fix recommendation.

- [ ] **Step 2: Reproduce and fix every material finding**

Use systematic debugging for failures and add a failing regression test before each code fix. Keep corrections in focused Conventional Commits and rerun the owning task's checks after every fix.

- [ ] **Step 3: Re-run the entire Task 9 matrix**

Require clean formatting, fatal-info analysis, every engine/wrapper/candidate/example test, zero-warning docs, passing API gate, passing external consumer, identical licenses, and successful Simulator smoke or a specific environment blocker.

- [ ] **Step 4: Obtain final Claude Opus manager review over CLI**

Resume manager session `385ea274-2785-45f7-ade6-aa943cffb929` with the frozen diff, verification results, and three reviewer reports. Resolve every concrete blocking directive before push.

- [ ] **Step 5: Push and create the focused stacked PR**

```bash
git status --short --branch
git push -u origin feat/ios26-package-dx
gh pr create \
  --repo notKleja/simple-stupid-ios-sheet \
  --base feat/synchronized-demo-video \
  --head feat/ios26-package-dx \
  --title "feat: improve iOS 26 package DX" \
  --body-file /private/tmp/ios26-package-dx-pr-body.md
```

Attach the pull request to this task. Do not merge it and do not publish a package or binary release.

- [ ] **Step 6: Deliver the engineering report**

Include Executive Summary, Research Findings, Developer Experience Improvements, Fork Preservation Report, Verification Report, DX Scorecard, Deferred Recommendations, and Final Verdict. Include exact test counts, commands, PR link, untested layers, and no unsupported parity claim.
