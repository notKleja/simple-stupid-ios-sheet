# Graph Report - flutter-engine  (2026-10-06)

## Corpus Check
- 112 files · ~74,748 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 54 file(s) not represented in the graph (top: .gz 32, (none) 7, .plist 4)

## Summary
- 1365 nodes · 1938 edges · 87 communities (67 shown, 20 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.95)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `89bfb1e6`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- compare.py
- ComparisonTests
- properties
- route.dart
- trace.schema.json
- stupid_simple_sheet.dart
- cupertino_sheet_copy.dart
- properties
- evidence.schema.json
- ios26.json
- ios27.json
- Master state
- Measurement + parity handoff
- example_card.dart
- Simple Stupid iOS Sheet
- FitTests
- example/lib/main.dart
- evidence.json
- profile.dart
- shrink_transition.dart
- CHANGELOG.md
- _
- Third-party notices
- Trace analysis
- artifacts/README.md
- docs/README.md
- flutter_reference/README.md
- CONTRACT.md
- measurement/README.md
- candidate/lib/main.dart
- stupid_simple_glass_sheet.dart
- stupid_simple_cupertino_sheet.dart
- native_reference/README.md
- DIFF_26_27.md
- _
- package:flutter/cupertino.dart
- playground_page.dart
- sheet_previews.dart
- .application
- StatelessWidget
- custom_route_example.dart
- snapping_point.dart
- trace.dart
- Cookbook
- package:stupid_simple_sheet/stupid_simple_sheet.dart
- Native iOS Sheet Parity Design
- snap_physics_test.dart
- package:flutter_test/flutter_test.dart
- non_draggable.dart
- route_test.dart
- share_sheet_example.dart
- type
- @immutable
- sheet_dismissal_transition.dart
- sheet_logo.dart
- Review Focus
- package:flutter/material.dart
- comparison_contract.dart
- StupidSimpleSheetRoute
- State
- Widget
- CustomPainter
- observed_profiles.dart
- simple_stupid_ios_sheet.dart
- Brother 2 — Flutter engine milestone
- items
- snapping_recipe.dart
- Flutter engine and opaque API
- content_sized_above_keyboard.dart
- slide_vs_shrink_recipe.dart
- example
- _SheetPlaygroundState
- id
- samples
- stddev
- trials
- contract_v2_pair/README.md
- flutter/README.md
- LaunchImage.imageset/README.md
- Runner-Bridging-Header.h
- candidate/README.md
- CONTRACT_V2.md
- DismissalMode
- sheet_constants.dart
- UPSTREAM.md
- ios
- unit

## God Nodes (most connected - your core abstractions)
1. `_` - 40 edges
2. `ComparisonTests` - 37 edges
3. `_` - 34 edges
4. `trace()` - 33 edges
5. `require()` - 22 edges
6. `RegressionTests` - 16 edges
7. `finite()` - 14 edges
8. `StupidSimpleSheetRoute` - 14 edges
9. `compare()` - 13 edges
10. `full_trace()` - 13 edges

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

## Communities (87 total, 20 thin omitted)

### Community 0 - "compare.py"
Cohesion: 0.08
Nodes (63): compare(), transitions(), finite(), indexed_events(), interpolate(), main(), metric_report(), First sample of final continuously in-band suffix; no unseen dwell inferred. (+55 more)

### Community 1 - "ComparisonTests"
Cohesion: 0.08
Nodes (12): ComparisonTests, config(), full_config(), full_trace(), Synthetic provenance-marker simulation for eligibility-gate tests only., trace(), InspectTests, complete_matrix() (+4 more)

### Community 2 - "properties"
Cohesion: 0.04
Nodes (45): enum, minimum, type, type, const, items, type, type (+37 more)

### Community 3 - "route.dart"
Cohesion: 0.02
Nodes (80): _activePointers, _animationChanged, _attach, backgroundColor, barrierColor, barrierDismissible, barrierLabel, buildContent (+72 more)

### Community 4 - "trace.schema.json"
Cohesion: 0.05
Nodes (45): type, allOf, $defs, nullableRect, size, exclusiveMinimum, minimum, type (+37 more)

### Community 5 - "stupid_simple_sheet.dart"
Cohesion: 0.03
Nodes (74): Duration get, allowSnapshotting, animateToRelative, animation, _animationTargetValue, backgroundSnapshotController, backgroundSnapshotMode, barrierColor (+66 more)

### Community 6 - "cupertino_sheet_copy.dart"
Cohesion: 0.04
Nodes (46): Animatable, double?, CopiedCupertinoSheetTransitions, extraPadding, fullTransition, getDeviceShape, getOverlayedChild, getRelativeTopPadding (+38 more)

### Community 7 - "properties"
Cohesion: 0.12
Nodes (16): enum, type, properties, type, type, confidence, formula, os_build (+8 more)

### Community 8 - "evidence.schema.json"
Cohesion: 0.25
Nodes (7): properties, schema_version, required, $schema, const, title, type

### Community 9 - "ios26.json"
Cohesion: 0.25
Nodes (7): major_version, measurements, platform, $schema, schema_version, status, unresolved

### Community 10 - "ios27.json"
Cohesion: 0.25
Nodes (7): major_version, measurements, platform, $schema, schema_version, status, unresolved

### Community 11 - "Master state"
Cohesion: 0.25
Nodes (7): Accepted facts, Active pull requests, Architecture, Current parity score, Master state, Next three highest-value tasks, Unresolved questions

### Community 12 - "Measurement + parity handoff"
Cohesion: 0.33
Nodes (5): Blockers / next decision, Implemented / verified, Measurement + parity handoff, PR #19 fix round 1, Recorded relationships — provisional, not accepted trajectories

### Community 13 - "example_card.dart"
Cohesion: 0.04
Nodes (47): borderColor, borderRadius, build, _buildFooter, _buildPreview, _cardRandom, CardSection, categoryId (+39 more)

### Community 14 - "Simple Stupid iOS Sheet"
Cohesion: 0.33
Nodes (5): Evidence policy, Repository layout, Simple Stupid iOS Sheet, Status, Upstream

### Community 16 - "example/lib/main.dart"
Cohesion: 0.05
Nodes (41): advanced/custom_route_example.dart, advanced/dynamic_content_example.dart, advanced/share_sheet_example.dart, _addItem, build, createState, dispose, DynamicContentExample (+33 more)

### Community 17 - "evidence.json"
Cohesion: 0.50
Nodes (3): entries, $schema, schema_version

### Community 18 - "profile.dart"
Cohesion: 0.05
Nodes (36): bottomInset, boundaryPoints, copyWith, cornerRadius, detentToVisibleHeight, dragResistance, environment, evidence (+28 more)

### Community 19 - "shrink_transition.dart"
Cohesion: 0.07
Nodes (34): Animation, AnimationWithParentMixin, @internal, class RenderShrinkTransition extends, double get, clamped, ClampedAnimation, ClampedAnimationX (+26 more)

### Community 20 - "CHANGELOG.md"
Cohesion: 0.06
Nodes (35): 0.0.2, 0.0.2-dev.0+1, 0.0.2-dev.1, 0.0.2-dev.2, 0.3.0, 0.3.0+1, 0.3.0-dev.0, 0.3.0-dev.1 (+27 more)

### Community 21 - "_"
Cohesion: 0.06
Nodes (35): _, accent, accentBlue, accentGold, accentGreen, accentIndigo, accentOrange, accentPurple (+27 more)

### Community 23 - "Trace analysis"
Cohesion: 0.25
Nodes (7): Comparison formulas, Current native relationship evidence, Fitting diagnostics, Matrix and holdouts, Record validation, Tolerances and repeat noise, Trace analysis

### Community 29 - "candidate/lib/main.dart"
Cohesion: 0.06
Nodes (32): dart:async, _active, _backgroundTouches, _beginTrace, build, _content, controller, createState (+24 more)

### Community 30 - "stupid_simple_glass_sheet.dart"
Cohesion: 0.06
Nodes (31): backgroundColor, backgroundSnapshotMode, _barrierColor, barrierDismissible, barrierLabel, blurBehindBarrier, buildContent, buildModalBarrier (+23 more)

### Community 31 - "stupid_simple_cupertino_sheet.dart"
Cohesion: 0.07
Nodes (29): DelegatedTransitionBuilder? get, backgroundColor, backgroundSnapshotMode, barrierColor, barrierDismissible, barrierLabel, buildContent, buildTransitions (+21 more)

### Community 34 - "_"
Cohesion: 0.07
Nodes (27): EdgeInsets, _, availableSize, contentHeight, custom, _DetentKind, displayScale, fraction (+19 more)

### Community 35 - "package:flutter/cupertino.dart"
Cohesion: 0.10
Nodes (20): dart:io, build, GlassSheetPreset, GlassSheetPreview, _push, BasicSheetPreview, build, showBasicSheet (+12 more)

### Community 36 - "playground_page.dart"
Cohesion: 0.08
Nodes (24): accentColor, _barrierDismissible, build, createState, _dismissalMode, _draggable, _initialSnap, interactive (+16 more)

### Community 37 - "sheet_previews.dart"
Cohesion: 0.09
Nodes (22): build, child, color, dashWidth, dotColor, dotRadius, fractions, gapWidth (+14 more)

### Community 38 - ".application"
Cohesion: 0.10
Nodes (15): Any, Bool, Darwin, Flutter, AppDelegate, SceneDelegate, RunnerTests, FlutterAppDelegate (+7 more)

### Community 39 - "StatelessWidget"
Cohesion: 0.10
Nodes (19): CalibrationContent, IosSheetCandidateApp, _CardGrid, _HomePage, _SubsectionLabel, _OpenButton, _OptionRow, PlaygroundPreview (+11 more)

### Community 40 - "custom_route_example.dart"
Cohesion: 0.11
Nodes (18): Color? get, DismissalMode get, _addItem, barrierColor, barrierDismissible, barrierLabel, build, buildContent (+10 more)

### Community 41 - "snapping_point.dart"
Cohesion: 0.11
Nodes (18): constantDeceleration, dragCoefficient, findClosestPoint, findClosestSnapPoint, findTargetSnapPoint, full, getAllPoints, hashCode (+10 more)

### Community 42 - "trace.dart"
Cohesion: 0.11
Nodes (17): comparison_contract.dart, _clock, event, eventWithProvenance, frame, implementationProvenance, IosSheetTraceRecorder, metrics (+9 more)

### Community 43 - "Cookbook"
Cohesion: 0.11
Nodes (17): Background snapshotting, Cookbook, Cupertino sheet, Custom routes (maximum control), Customizing preset routes, Glass sheet (iOS 26), Important, Installation (+9 more)

### Community 44 - "package:stupid_simple_sheet/stupid_simple_sheet.dart"
Cohesion: 0.12
Nodes (15): AssertionError, main, basedir, compare, findTargetSnapPoint, _maxPixelMismatchCount, PixelDiffGoldenComparator, target (+7 more)

### Community 45 - "Native iOS Sheet Parity Design"
Cohesion: 0.12
Nodes (15): Analyzer and regression system, Delivery sequence, Evidence and profiles, Failure handling, Flutter package and candidate harness, Flutter semantic model, Intent, Measurement contracts (+7 more)

### Community 46 - "snap_physics_test.dart"
Cohesion: 0.18
Nodes (11): @Deprecated, _LargestSnapPhysics, AbsoluteSnapPhysics, FlingSnapPhysics, FrictionSnapPhysics, LegacySnapPhysics, RelativeSnapPhysics, SnapPhysics (+3 more)

### Community 47 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.21
Nodes (9): dart:convert, environment, main, base, main, main, package:flutter_test/flutter_test.dart, package:flutter/widgets.dart (+1 more)

### Community 48 - "non_draggable.dart"
Cohesion: 0.18
Nodes (10): bool get, build, _canPop, createState, _CustomDraggabilityRoute, dispose, draggable, _draggableNotifier (+2 more)

### Community 49 - "route_test.dart"
Cohesion: 0.18
Nodes (10): ChangeNotifier, IosSheetController, backgroundTaps, controller, findTargetSnapPoint, main, navigator, present (+2 more)

### Community 50 - "share_sheet_example.dart"
Cohesion: 0.18
Nodes (10): Color?, build, color, _Contact, _contacts, initials, name, ShareSheetExample (+2 more)

### Community 51 - "type"
Cohesion: 0.18
Nodes (11): items, type, type, items, type, hypotheses, limitations, run_ids (+3 more)

### Community 52 - "@immutable"
Cohesion: 0.20
Nodes (10): @immutable, IosSheetDetent, IosSheetEnvironment, ResolvedIosDetent, IosSheetGeometry, IosSheetGeometryContext, IosSheetProfile, IosSheetResistanceContext (+2 more)

### Community 53 - "sheet_dismissal_transition.dart"
Cohesion: 0.20
Nodes (9): dart:math, animation, build, child, dismissalMode, referenceHeightOf, SheetDismissalTransition, package:stupid_simple_sheet/src/dismissal_mode.dart (+1 more)

### Community 54 - "sheet_logo.dart"
Cohesion: 0.20
Nodes (9): dart:ui, build, deviceColor, gestureColor, paint, sheetColor, SheetLogo, shouldRepaint (+1 more)

### Community 55 - "Review Focus"
Cohesion: 0.20
Nodes (9): Global Constraints, Native iOS Sheet Parity Integration Plan, Review Focus, Task 1: Integrate the measurement contract, Task 2: Integrate the analyzer and regression matrix, Task 3: Integrate the native reference harness, Task 4: Integrate the Flutter engine and public API, Task 5: Reconcile contracts and complete measured profiles (+1 more)

### Community 56 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (8): main, buildApp, isSnapshotting, main, motion, package:flutter/material.dart, package:ios_sheet_candidate/main.dart, SnapshotWidget

### Community 57 - "comparison_contract.dart"
Cohesion: 0.20
Nodes (9): canonicalIosDetentIdentifier, canonicalIosSheetConfiguration, detents, iosPageReferenceConfiguration, iosSheetComparisonConfigurationKeys, largest, rawDetents, undimmed (+1 more)

### Community 58 - "StupidSimpleSheetRoute"
Cohesion: 0.60
Nodes (10): StupidSimpleIosSheetRoute, CustomSheetRoute, StupidSimpleCupertinoSheetRoute, StupidSimpleGlassSheetRoute, StupidSimpleSheetController, StupidSimpleSheetRoute, StupidSimpleSheetTransitionMixin, main (+2 more)

### Community 59 - "State"
Cohesion: 0.27
Nodes (10): CustomRouteExample, _CustomRouteExampleState, PlaygroundPage, _PlaygroundPageState, _NonDraggableSheet, __NonDraggableSheetState, _RelativeGestureDetector, _RelativeGestureDetectorState (+2 more)

### Community 60 - "Widget"
Cohesion: 0.25
Nodes (7): Clip, build, child, clipBehavior, shape, ShapeBorder, Widget

### Community 61 - "CustomPainter"
Cohesion: 0.29
Nodes (7): CustomPainter, _RulerPainter, _InnerShadowPainter, _SheetLogoPainter, DashedLinePainter, DotGridPainter, LineGridPainter

### Community 62 - "observed_profiles.dart"
Cohesion: 0.29
Nodes (6): detents.dart, copyWith, fallback, observedPage402x874Profile, requireScope, profile.dart

### Community 63 - "simple_stupid_ios_sheet.dart"
Cohesion: 0.29
Nodes (6): src/comparison_contract.dart, src/detents.dart, src/observed_profiles.dart, src/profile.dart, src/route.dart, src/trace.dart

### Community 64 - "Brother 2 — Flutter engine milestone"
Cohesion: 0.29
Nodes (6): Brother 2 — Flutter engine milestone, Changed areas, Conclusions, Review round 1, Runtime proof and tests, Uncertainty / blockers / next decision

### Community 65 - "items"
Cohesion: 0.29
Nodes (7): items, type, items, type, required, artifacts, entries

### Community 66 - "snapping_recipe.dart"
Cohesion: 0.33
Nodes (5): build, _colorForStop, showSnappingSheet, SnappingPreview, snaps

### Community 67 - "Flutter engine and opaque API"
Cohesion: 0.40
Nodes (4): Architecture map, Flutter engine and opaque API, Profile discipline, Public capability scope

### Community 68 - "content_sized_above_keyboard.dart"
Cohesion: 0.40
Nodes (4): build, _Content, ContentSizedKeyboardPreview, showContentSizedKeyboardSheet

### Community 69 - "slide_vs_shrink_recipe.dart"
Cohesion: 0.40
Nodes (4): build, _show, SlideVsShrinkPreview, SlideVsShrinkRecipe

### Community 70 - "example"
Cohesion: 0.40
Nodes (4): Assets, example, Getting Started, Localization

### Community 71 - "_SheetPlaygroundState"
Cohesion: 0.67
Nodes (3): SheetPlayground, _SheetPlaygroundState, TickerProviderStateMixin

### Community 72 - "id"
Cohesion: 0.67
Nodes (3): minLength, type, id

### Community 73 - "samples"
Cohesion: 0.67
Nodes (3): samples, minimum, type

### Community 74 - "stddev"
Cohesion: 0.67
Nodes (3): stddev, minimum, type

### Community 75 - "trials"
Cohesion: 0.67
Nodes (3): trials, minimum, type

## Knowledge Gaps
- **783 isolated node(s):** `Darwin`, `XCTest`, `_metadata`, `_major`, `_undimmed` (+778 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 924 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **20 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `share_sheet_example.dart`, `package:flutter/cupertino.dart`, `playground_page.dart`, `_`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `observed_profiles.dart`, `@immutable`, `cupertino_sheet_copy.dart`, `package:flutter_test/flutter_test.dart`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Why does `IosSheetController` connect `route_test.dart` to `route.dart`, `candidate/lib/main.dart`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **What connects `Darwin`, `XCTest`, `_metadata` to the rest of the system?**
  _783 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `compare.py` be split into smaller, more focused modules?**
  _Cohesion score 0.0763963963963964 - nodes in this community are weakly interconnected._
- **Should `ComparisonTests` be split into smaller, more focused modules?**
  _Cohesion score 0.0818452380952381 - nodes in this community are weakly interconnected._
- **Should `properties` be split into smaller, more focused modules?**
  _Cohesion score 0.044444444444444446 - nodes in this community are weakly interconnected._