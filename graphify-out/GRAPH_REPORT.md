# Graph Report - flutter-engine  (2026-10-06)

## Corpus Check
- 85 files · ~64,801 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 53 file(s) not represented in the graph (top: .gz 32, (none) 6, .plist 4)

## Summary
- 1031 nodes · 1342 edges · 64 communities (47 shown, 17 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `57fc91d2`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- stupid_simple_sheet.dart
- route.dart
- example_card.dart
- package:flutter_test/flutter_test.dart
- sheet_previews.dart
- candidate/lib/main.dart
- profile.dart
- shrink_transition.dart
- CHANGELOG.md
- sheet_background.dart
- _
- cupertino_sheet_copy.dart
- stupid_simple_glass_sheet.dart
- example/lib/main.dart
- snapping_point.dart
- stupid_simple_cupertino_sheet.dart
- _
- playground_page.dart
- .application
- custom_route_example.dart
- Cookbook
- package:stupid_simple_sheet_example/widgets/example_theme.dart
- StatelessWidget
- stupid_simple_sheet_test.dart
- trace.dart
- comparison_contract.dart
- share_sheet_example.dart
- @immutable
- route_test.dart
- example_logo_test.dart
- package:flutter/cupertino.dart
- ios26.json
- ios27.json
- Master state
- observed_profiles.dart
- simple_stupid_ios_sheet.dart
- snapping_recipe.dart
- Simple Stupid iOS Sheet
- Flutter engine and opaque API
- package:flutter/material.dart
- glass_sheet_preset.dart
- cupertino_sheet_preset.dart
- example
- evidence.json
- Third-party notices
- analysis/README.md
- artifacts/README.md
- docs/README.md
- LaunchImage.imageset/README.md
- Runner-Bridging-Header.h
- candidate/README.md
- DismissalMode
- sheet_constants.dart
- flutter_reference/README.md
- UPSTREAM.md
- measurement/README.md
- native_reference/README.md
- DIFF_26_27.md
- route_snapshot_mode_test.dart
- Brother 2 — Flutter engine milestone
- package:stupid_simple_sheet/stupid_simple_sheet.dart
- flutter/README.md
- contract_v2_pair/README.md
- CONTRACT_V2.md

## God Nodes (most connected - your core abstractions)
1. `_` - 40 edges
2. `_` - 34 edges
3. `StupidSimpleSheetRoute` - 14 edges
4. `Cookbook` - 13 edges
5. `StupidSimpleSheetTransitionMixin` - 11 edges
6. `StupidSimpleGlassSheetRoute` - 9 edges
7. `StupidSimpleSheetController` - 9 edges
8. `StupidSimpleCupertinoSheetRoute` - 7 edges
9. `Master state` - 7 edges
10. `StupidSimpleIosSheetRoute` - 6 edges

## Surprising Connections (you probably didn't know these)
- `main` --navigates--> `StupidSimpleIosSheetRoute`  [EXTRACTED]
  flutter_reference/packages/ios_sheet/test/route_test.dart → flutter_reference/packages/ios_sheet/lib/src/route.dart
- `_openSheet` --navigates--> `StupidSimpleSheetRoute`  [EXTRACTED]
  flutter_reference/packages/stupid_simple_sheet/example/lib/playground/playground_page.dart → flutter_reference/packages/stupid_simple_sheet/lib/stupid_simple_sheet.dart
- `_push` --navigates--> `StupidSimpleCupertinoSheetRoute`  [EXTRACTED]
  flutter_reference/packages/stupid_simple_sheet/example/lib/presets/cupertino_sheet_preset.dart → flutter_reference/packages/stupid_simple_sheet/lib/src/stupid_simple_cupertino_sheet.dart
- `_push` --navigates--> `StupidSimpleGlassSheetRoute`  [EXTRACTED]
  flutter_reference/packages/stupid_simple_sheet/example/lib/presets/glass_sheet_preset.dart → flutter_reference/packages/stupid_simple_sheet/lib/src/stupid_simple_glass_sheet.dart
- `showBasicSheet` --navigates--> `StupidSimpleSheetRoute`  [EXTRACTED]
  flutter_reference/packages/stupid_simple_sheet/example/lib/recipes/basic_sheet.dart → flutter_reference/packages/stupid_simple_sheet/lib/stupid_simple_sheet.dart

## Import Cycles
- None detected.

## Communities (64 total, 17 thin omitted)

### Community 0 - "stupid_simple_sheet.dart"
Cohesion: 0.03
Nodes (74): Duration get, allowSnapshotting, animateToRelative, animation, _animationTargetValue, backgroundSnapshotController, backgroundSnapshotMode, barrierColor (+66 more)

### Community 1 - "route.dart"
Cohesion: 0.02
Nodes (80): _activePointers, _animationChanged, _attach, backgroundColor, barrierColor, barrierDismissible, barrierLabel, buildContent (+72 more)

### Community 2 - "example_card.dart"
Cohesion: 0.04
Nodes (44): borderColor, borderRadius, build, _buildFooter, _buildPreview, _cardRandom, CardSection, categoryId (+36 more)

### Community 3 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.21
Nodes (9): dart:convert, environment, main, base, main, main, package:flutter_test/flutter_test.dart, package:flutter/widgets.dart (+1 more)

### Community 4 - "sheet_previews.dart"
Cohesion: 0.05
Nodes (39): CustomPainter, dart:math, dart:ui, _RulerPainter, _InnerShadowPainter, build, deviceColor, gestureColor (+31 more)

### Community 5 - "candidate/lib/main.dart"
Cohesion: 0.06
Nodes (32): dart:async, _active, _backgroundTouches, _beginTrace, build, _content, controller, createState (+24 more)

### Community 6 - "profile.dart"
Cohesion: 0.05
Nodes (36): bottomInset, boundaryPoints, copyWith, cornerRadius, detentToVisibleHeight, dragResistance, environment, evidence (+28 more)

### Community 7 - "shrink_transition.dart"
Cohesion: 0.07
Nodes (34): Animation, AnimationWithParentMixin, @internal, class RenderShrinkTransition extends, double get, clamped, ClampedAnimation, ClampedAnimationX (+26 more)

### Community 8 - "CHANGELOG.md"
Cohesion: 0.06
Nodes (35): 0.0.2, 0.0.2-dev.0+1, 0.0.2-dev.1, 0.0.2-dev.2, 0.3.0, 0.3.0+1, 0.3.0-dev.0, 0.3.0-dev.1 (+27 more)

### Community 9 - "sheet_background.dart"
Cohesion: 0.06
Nodes (32): Clip, double?, build, child, clipBehavior, shape, backgroundColor, build (+24 more)

### Community 10 - "_"
Cohesion: 0.06
Nodes (35): _, accent, accentBlue, accentGold, accentGreen, accentIndigo, accentOrange, accentPurple (+27 more)

### Community 11 - "cupertino_sheet_copy.dart"
Cohesion: 0.06
Nodes (30): Animatable, CopiedCupertinoSheetTransitions, extraPadding, fullTransition, getDeviceShape, getOverlayedChild, getRelativeTopPadding, height (+22 more)

### Community 12 - "stupid_simple_glass_sheet.dart"
Cohesion: 0.06
Nodes (31): backgroundColor, backgroundSnapshotMode, _barrierColor, barrierDismissible, barrierLabel, blurBehindBarrier, buildContent, buildModalBarrier (+23 more)

### Community 13 - "example/lib/main.dart"
Cohesion: 0.05
Nodes (41): advanced/custom_route_example.dart, advanced/dynamic_content_example.dart, advanced/share_sheet_example.dart, _addItem, build, createState, dispose, DynamicContentExample (+33 more)

### Community 14 - "snapping_point.dart"
Cohesion: 0.08
Nodes (27): @Deprecated, _LargestSnapPhysics, AbsoluteSnapPhysics, constantDeceleration, dragCoefficient, findClosestPoint, findClosestSnapPoint, findTargetSnapPoint (+19 more)

### Community 15 - "stupid_simple_cupertino_sheet.dart"
Cohesion: 0.07
Nodes (29): DelegatedTransitionBuilder? get, backgroundColor, backgroundSnapshotMode, barrierColor, barrierDismissible, barrierLabel, buildContent, buildTransitions (+21 more)

### Community 16 - "_"
Cohesion: 0.07
Nodes (27): EdgeInsets, _, availableSize, contentHeight, custom, _DetentKind, displayScale, fraction (+19 more)

### Community 17 - "playground_page.dart"
Cohesion: 0.08
Nodes (24): accentColor, _barrierDismissible, build, createState, _dismissalMode, _draggable, _initialSnap, interactive (+16 more)

### Community 18 - ".application"
Cohesion: 0.10
Nodes (15): Any, Bool, Darwin, Flutter, AppDelegate, SceneDelegate, RunnerTests, FlutterAppDelegate (+7 more)

### Community 19 - "custom_route_example.dart"
Cohesion: 0.05
Nodes (44): bool get, Color? get, DismissalMode get, SheetPlayground, _SheetPlaygroundState, _addItem, barrierColor, barrierDismissible (+36 more)

### Community 20 - "Cookbook"
Cohesion: 0.11
Nodes (17): Background snapshotting, Cookbook, Cupertino sheet, Custom routes (maximum control), Customizing preset routes, Glass sheet (iOS 26), Important, Installation (+9 more)

### Community 21 - "package:stupid_simple_sheet_example/widgets/example_theme.dart"
Cohesion: 0.16
Nodes (11): BasicSheetPreview, build, showBasicSheet, build, ContentSizedPreview, showContentSizedSheet, build, showStickyFooterSheet (+3 more)

### Community 22 - "StatelessWidget"
Cohesion: 0.13
Nodes (15): CalibrationContent, IosSheetCandidateApp, _CardGrid, _HomePage, _SubsectionLabel, _OpenButton, _OptionRow, PlaygroundPreview (+7 more)

### Community 23 - "stupid_simple_sheet_test.dart"
Cohesion: 0.17
Nodes (21): AssertionError, StupidSimpleIosSheetRoute, CustomSheetRoute, StupidSimpleCupertinoSheetRoute, StupidSimpleGlassSheetRoute, StupidSimpleSheetController, StupidSimpleSheetRoute, StupidSimpleSheetTransitionMixin (+13 more)

### Community 24 - "trace.dart"
Cohesion: 0.11
Nodes (17): comparison_contract.dart, _clock, event, eventWithProvenance, frame, implementationProvenance, IosSheetTraceRecorder, metrics (+9 more)

### Community 25 - "comparison_contract.dart"
Cohesion: 0.20
Nodes (9): canonicalIosDetentIdentifier, canonicalIosSheetConfiguration, detents, iosPageReferenceConfiguration, iosSheetComparisonConfigurationKeys, largest, rawDetents, undimmed (+1 more)

### Community 26 - "share_sheet_example.dart"
Cohesion: 0.18
Nodes (10): Color?, build, color, _Contact, _contacts, initials, name, ShareSheetExample (+2 more)

### Community 27 - "@immutable"
Cohesion: 0.20
Nodes (10): @immutable, IosSheetDetent, IosSheetEnvironment, ResolvedIosDetent, IosSheetGeometry, IosSheetGeometryContext, IosSheetProfile, IosSheetResistanceContext (+2 more)

### Community 28 - "route_test.dart"
Cohesion: 0.18
Nodes (10): ChangeNotifier, IosSheetController, backgroundTaps, controller, findTargetSnapPoint, main, navigator, present (+2 more)

### Community 29 - "example_logo_test.dart"
Cohesion: 0.40
Nodes (4): dart:io, main, package:snaptest/snaptest.dart, package:stupid_simple_sheet_example/widgets/sheet_logo.dart

### Community 30 - "package:flutter/cupertino.dart"
Cohesion: 0.25
Nodes (6): build, _show, SlideVsShrinkPreview, SlideVsShrinkRecipe, RouteSnapshotMode, package:flutter/cupertino.dart

### Community 31 - "ios26.json"
Cohesion: 0.25
Nodes (7): major_version, measurements, platform, $schema, schema_version, status, unresolved

### Community 32 - "ios27.json"
Cohesion: 0.25
Nodes (7): major_version, measurements, platform, $schema, schema_version, status, unresolved

### Community 33 - "Master state"
Cohesion: 0.25
Nodes (7): Accepted facts, Active pull requests, Architecture, Current parity score, Master state, Next three highest-value tasks, Unresolved questions

### Community 34 - "observed_profiles.dart"
Cohesion: 0.29
Nodes (6): detents.dart, copyWith, fallback, observedPage402x874Profile, requireScope, profile.dart

### Community 35 - "simple_stupid_ios_sheet.dart"
Cohesion: 0.29
Nodes (6): src/comparison_contract.dart, src/detents.dart, src/observed_profiles.dart, src/profile.dart, src/route.dart, src/trace.dart

### Community 36 - "snapping_recipe.dart"
Cohesion: 0.33
Nodes (5): build, _colorForStop, showSnappingSheet, SnappingPreview, snaps

### Community 37 - "Simple Stupid iOS Sheet"
Cohesion: 0.33
Nodes (5): Evidence policy, Repository layout, Simple Stupid iOS Sheet, Status, Upstream

### Community 38 - "Flutter engine and opaque API"
Cohesion: 0.40
Nodes (4): Architecture map, Flutter engine and opaque API, Profile discipline, Public capability scope

### Community 39 - "package:flutter/material.dart"
Cohesion: 0.33
Nodes (4): main, main, package:flutter/material.dart, package:ios_sheet_candidate/main.dart

### Community 40 - "glass_sheet_preset.dart"
Cohesion: 0.40
Nodes (4): build, GlassSheetPreset, GlassSheetPreview, _push

### Community 41 - "cupertino_sheet_preset.dart"
Cohesion: 0.40
Nodes (4): build, CupertinoSheetPreset, CupertinoSheetPreview, _push

### Community 42 - "example"
Cohesion: 0.40
Nodes (4): Assets, example, Getting Started, Localization

### Community 43 - "evidence.json"
Cohesion: 0.50
Nodes (3): entries, $schema, schema_version

### Community 58 - "route_snapshot_mode_test.dart"
Cohesion: 0.33
Nodes (5): buildApp, isSnapshotting, main, motion, SnapshotWidget

### Community 59 - "Brother 2 — Flutter engine milestone"
Cohesion: 0.29
Nodes (6): Brother 2 — Flutter engine milestone, Changed areas, Conclusions, Review round 1, Runtime proof and tests, Uncertainty / blockers / next decision

### Community 60 - "package:stupid_simple_sheet/stupid_simple_sheet.dart"
Cohesion: 0.22
Nodes (7): build, _Content, ContentSizedKeyboardPreview, showContentSizedKeyboardSheet, main, package:flutter/gestures.dart, package:stupid_simple_sheet/stupid_simple_sheet.dart

## Knowledge Gaps
- **672 isolated node(s):** `Darwin`, `XCTest`, `_metadata`, `_major`, `_undimmed` (+667 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 788 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `package:flutter_test/flutter_test.dart`, `sheet_background.dart`, `observed_profiles.dart`, `@immutable`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `_`, `playground_page.dart`, `share_sheet_example.dart`, `package:flutter/cupertino.dart`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Why does `SheetSnappingConfig` connect `@immutable` to `stupid_simple_sheet.dart`, `stupid_simple_glass_sheet.dart`, `snapping_point.dart`, `stupid_simple_cupertino_sheet.dart`, `custom_route_example.dart`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **What connects `Darwin`, `XCTest`, `_metadata` to the rest of the system?**
  _672 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `stupid_simple_sheet.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02666666666666667 - nodes in this community are weakly interconnected._
- **Should `route.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.024691358024691357 - nodes in this community are weakly interconnected._
- **Should `example_card.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.044444444444444446 - nodes in this community are weakly interconnected._