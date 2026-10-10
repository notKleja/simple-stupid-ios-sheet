# iOS 26 Package Developer Experience Design

**Date:** 2026-10-11  
**Status:** Approved in chat; written specification awaiting review  
**Branch:** `feat/ios26-package-dx`  
**Base:** `feat/synchronized-demo-video` at `db18f75f8c47b90f1f3a4f797a0f14f140b7b7df`

## Purpose

Make `simple_stupid_ios_sheet` straightforward to discover, install for local
development, integrate, configure, troubleshoot, test, and maintain while
making iOS 26 its only supported native-reference scope.

This is a developer-experience and packaging pass. It does not add new native
sheet behavior, claim complete iOS 26 parity, publish a package, or delete
historical iOS 27 research evidence.

## Success criteria

A Flutter developer can:

1. Understand the package, its evidence boundary, and its supported reference
   scope from the package README.
2. Clone the repository, add the package by a documented local path, and run a
   minimal iOS 26 sheet example without reading implementation files.
3. Use a familiar `showIos26Sheet<T>` helper for common presentation while
   retaining direct route construction for advanced use.
4. Diagnose common detent and controller lifecycle errors from documentation.
5. Distinguish supported APIs, advanced seams, diagnostics, and research-only
   facilities without new untested library entrypoints.
6. Reproduce formatting, analysis, tests, docs, example checks, and public API
   compatibility checks locally and in CI.

The implementation is accepted only when existing behavior remains covered,
the new helper matches direct route construction at observable boundaries, and
the work is independently reviewed for compatibility, DX, and legal/platform
risk.

## Evidence and baseline

Baseline at `db18f75` on Flutter 3.44.6 and Dart 3.12.2:

- `flutter analyze packages/ios_sheet`: no issues.
- `flutter test packages/ios_sheet`: 105 tests passed.
- `dart doc --dry-run .`: zero errors and one unresolved reference warning.
- `dart pub publish --dry-run`: blocked by missing package-local `LICENSE`,
  `README.md`, and `CHANGELOG.md`; also reported missing repository metadata.
- The package has no package-local example, contributor guide, CI workflow, or
  high-level `show...` presentation helper.
- The interactive candidate defaults to iOS 27 and exposes a 26/27 selector.

Three independent audits confirmed that the wrapper compiles against local
engine seams which are absent from the published
`stupid_simple_sheet 1.0.0-dev.4`. Resolving the wrapper against that published
package produces 18 analyzer issues. Workspace success therefore does not
establish standalone consumer compatibility.

## Preservation contract

### Preserve

- Existing `simple_stupid_ios_sheet` public symbols, constructors, defaults,
  callback ordering, exception classes, detent semantics, controller behavior,
  trace/comparison formats, and current selective engine re-exports.
- The generic engine behavior and its existing test suite.
- The separation between interactive dismissal locking and explicit
  controller dismissal.
- Unknown-version and out-of-domain failures; no silent profile substitution.
- The distinction among fallback, observed, accepted, and unavailable
  evidence.
- The no-Liquid-Glass boundary in the opaque package and example.
- Original upstream MIT license, copyright, attribution, version provenance,
  archive hash, and imported test history.
- Historical iOS 27 traces, specifications, measurements, and reports as
  immutable research evidence.

### Explicitly authorized change

The locally extended transition engine must no longer reuse the published
package identity and version. It will become:

```yaml
name: ios_sheet_engine
version: 1.0.0-dev.4+fork.1
```

The source package directory will be renamed from
`packages/stupid_simple_sheet` to `packages/ios_sheet_engine`. Internal imports
and workspace dependencies will follow the new identity. Public engine class
names and runtime behavior remain unchanged in this pass.

The engine retains its upstream `LICENSE`, changelog history, source notices,
and explicit fork provenance. This identity change prevents dependency
resolution from silently selecting the incompatible published package.

`simple_stupid_ios_sheet` remains unpublished and uses the sibling engine by
an explicit local path until both packages have a valid hosted distribution
boundary. The documented install flow is clone plus local path. No pub.dev or
Git-subdirectory installation claim is made without an isolated consumer test.
The wrapper advances from `0.1.0-dev.1` to `0.1.0-dev.2`; its changelog records
the additive helper, iOS 26 scope, deprecations, and engine-identity migration.

## iOS 26 support contract

- iOS 26 is the sole developer-facing native reference.
- Running on later iOS versions may be tested for forward compatibility, but
  does not imply native parity with those versions.
- No host-OS auto-detection silently selects an unmeasured profile.
- `IosSheetProfile.ios26` remains the explicit fallback profile.
- A new strict resolver accepts only major version 26 and rejects every other
  value with `UnsupportedError`.
- A public constant exposes the supported reference version set `{26}`.
- `IosSheetProfile.ios27` remains behaviorally unchanged but is deprecated as
  an unsupported legacy/research fallback.
- `IosSheetProfile.forMajorVersion` remains behaviorally unchanged for source
  compatibility but is deprecated in favor of the strict iOS 26 resolver.
- `observedPage402x874Profile(int)` remains compatible and deprecated. A new
  zero-argument iOS 26-named function exposes the qualified profile without a
  version parameter.
- Deprecation compatibility tests suppress only the intentional
  `deprecated_member_use_from_same_package` diagnostics. The complete package
  must pass `flutter analyze --fatal-infos`.
- The candidate defaults to iOS 26 and removes the visible version selector.
  Any retained iOS 27 replay switch is internal research plumbing and absent
  from developer-facing documentation.

## Developer-facing API

### Common path

Add an exported helper with this conceptual shape:

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
});
```

The implementation is a thin adapter:

1. Select `Navigator.of(context, rootNavigator: useRootNavigator)`.
2. Construct the existing route with `IosSheetProfile.ios26`.
3. Build content through the supplied `WidgetBuilder`.
4. Forward every accepted option without reinterpretation.
5. Return the exact `Navigator.push<T>` result.

The helper never owns or disposes a caller-provided controller. When no
controller is provided, callers do not acquire a controller lifecycle
obligation.

### Advanced path

`StupidSimpleIosSheetRoute<T>` remains the advanced API. Its existing
constructor stays source-compatible and continues to require an explicit
profile. Adding an optional barrier label is allowed only if the existing
English default remains unchanged.

### Entrypoints

Do not add `core.dart`, `experimental.dart`, or `diagnostics.dart` in this
change. Their maintenance and compatibility costs are deferred until there is
a concrete consumer journey and dedicated test matrix for each entrypoint.

Instead, the existing barrel receives:

- a library-level doc comment;
- a supported/advanced/diagnostic/research classification in package docs;
- the new helper and iOS 26 support declarations;
- no removed exports.

## Package assets and developer journey

Add to `packages/ios_sheet`:

- `README.md`: purpose, iOS 26 scope, evidence warning, clone/path install,
  minimal helper example, direct-route example, controller ownership,
  supported/fallback/unavailable table, troubleshooting links, and attribution.
- `CHANGELOG.md`: `0.1.0-dev.2` DX changes and compatibility notes.
- `LICENSE`: fork license plus preserved upstream attribution references.
- `example/`: one dependency-light Flutter application using only the public
  barrel and the supported iOS 26 flow.
- `doc/troubleshooting.md`: configuration and lifecycle failures with recovery
  guidance.
- `CONTRIBUTING.md`: exact workspace commands and evidence-layer boundaries.

Update:

- package metadata with repository, issue tracker, documentation, and relevant
  topics, wrapper version `0.1.0-dev.2`, and an explicit sibling-path
  dependency on `ios_sheet_engine` while retaining `publish_to: none`;
- root README, Flutter architecture, candidate README, and candidate UI so the
  supported product scope is iOS 26 and iOS 27 material is labeled historical
  research;
- malformed candidate README spacing and generated placeholder descriptions.

Do not rewrite historical specs, traces, or parity reports merely to remove
iOS 27 text.

## Fork provenance

Add a concise fork provenance and compatibility matrix documenting:

- original project and package identity;
- exact published archive version and SHA-256;
- upstream tag and observed head as corroborating evidence;
- import commit;
- fork-specific engine seams;
- wrapper revision and purpose;
- current support/reference claims;
- license and notice obligations;
- future upstream-sync strategy and risks.

The immutable pub.dev archive remains the exact base identifier. Current
upstream HEAD is not substituted for that provenance.

## Public API surface gate

The compatibility gate is concrete and checked in:

1. Run `dart doc` for `packages/ios_sheet` into an ignored build directory.
2. `tool/update_api_surface.dart` reads dartdoc's `index.json` and emits a
   deterministic sorted JSON array containing each public entry's library,
   qualified name, kind, and enclosing owner.
3. Include public and inherited members exposed on
   `StupidSimpleIosSheetRoute` because consumers can call them.
4. Commit the generated baseline as `tool/api_surface.json`.
5. `tool/check_api_surface.dart` regenerates the normalized representation and
   fails when a baseline symbol is removed or changes kind/owner. Additions are
   printed for review but do not fail.
6. Constructor and callback signatures that dartdoc's symbol index cannot
   express are covered by compile fixtures for the existing route/controller
   API, deprecated iOS 27 compatibility API, new helper, and selective engine
   re-exports.
7. CI runs doc generation, the surface check, and all compile fixtures.

The tool uses only Dart SDK libraries. No analyzer or code-generation runtime
dependency is added to the package.

## Testing

### Helper/direct-route parity

Widget tests compare `showIos26Sheet` with direct construction for:

- exact pop result propagation for `T`;
- nested versus root navigator selection through `useRootNavigator`;
- `RouteSettings` identity and values as observed from the active route;
- detents and initial selection;
- modal/undimmed threshold behavior;
- dismissal policy and callbacks;
- controller attachment/detachment and caller ownership;
- supplied/default barrier labels;
- absence of any iOS profile other than `IosSheetProfile.ios26`.

### Scope and compatibility

- strict reference resolution accepts 26 and rejects 27 and unknown versions;
- deprecated `ios27`, `forMajorVersion(27)`, and the old observed-profile
  function retain prior behavior and compile under targeted ignore comments;
- no code maps iOS 27 to the iOS 26 profile;
- candidate widget tests confirm that the visible target is iOS 26 and no
  version selector is present;
- public API compile fixtures preserve existing imports and calls;
- the package example builds and has a smoke widget test.

### Full verification matrix

- `dart format --output=none --set-exit-if-changed` on changed Dart files.
- `flutter analyze --fatal-infos` for engine, wrapper, candidate, and example.
- engine tests, existing 105 wrapper tests, candidate tests, and new tests.
- `dart doc --dry-run` with zero warnings.
- API-surface gate and compile fixtures.
- isolated clone/path consumer `pub get`, analyze, test, and iOS build.
- `dart pub publish --dry-run` as a diagnostic only; publication remains
  forbidden and path-dependency errors are documented until hosting exists.
- iOS 26 simulator Debug and Release build/launch smoke checks where available.
- Git diff/status checks to ensure generated files and unrelated work are not
  committed.

## CI

Add a focused workflow that runs on the new DX branch and pull requests:

- dependency resolution;
- formatting check;
- fatal-info analysis;
- engine, wrapper, candidate, and example tests;
- dartdoc warning check;
- API-surface gate;
- isolated local-path consumer check.

Native simulator jobs remain local verification unless a suitable macOS runner
and iOS 26 runtime are explicitly configured. CI must not label host-only checks
as native-runtime parity.

## Implementation boundaries

Do not include:

- new native sheet behavior or parity claims;
- removal of iOS 27 research artifacts;
- removal of existing wrapper exports;
- new experimental or diagnostics entrypoints;
- public async-controller redesign;
- package publication or a new binary release;
- dependency major upgrades or broad formatting;
- upstream merge unrelated to the approved identity/DX work.

## Review and delivery

Implementation occurs on `feat/ios26-package-dx`, based on
`feat/synchronized-demo-video`. The pull request is stacked with base
`feat/synchronized-demo-video` so its diff contains only package-DX work.

After implementation and local verification, three fresh read-only reviews
must independently cover:

1. public API and behavioral compatibility;
2. first-use, troubleshooting, contribution, and upgrade DX;
3. platform, dependency, security, licensing, and attribution boundaries.

Material findings are fixed and affected checks rerun. Commits use short
one-line Conventional Commit messages without attribution trailers. The branch
is pushed only after the full local verification report is assembled.

## Deferred decisions

- Hosting or publishing `ios_sheet_engine` and `simple_stupid_ios_sheet`.
- Removing deprecated iOS 27 APIs in a semver-signaled breaking release.
- Replacing public engine inheritance with private composition.
- Splitting core, experimental, and diagnostics entrypoints.
- Adding async typed controller results.
- Applying Reduce Motion, VoiceOver focus/escape, and other unmeasured native
  behavior.
- Updating dependency ranges or performing a broad upstream merge.

## Current guidance consulted

Verified 2026-10-11:

- Flutter package development:
  <https://docs.flutter.dev/packages-and-plugins/developing-packages>
- Effective Dart documentation:
  <https://dart.dev/effective-dart/documentation>
- Dart package layout:
  <https://dart.dev/tools/pub/package-layout>
- Dart documentation generation:
  <https://dart.dev/tools/dart-doc>
- Pub scoring:
  <https://pub.dev/help/scoring>

