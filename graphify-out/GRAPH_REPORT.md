# Graph Report - flutter-engine  (2026-10-06)

## Corpus Check
- 81 files · ~48,702 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 51 file(s) not represented in the graph (top: .gz 30, (none) 6, .plist 4)

## Summary
- 996 nodes · 1310 edges · 62 communities (47 shown, 15 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `ba715f42`
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
- non_draggable.dart
- sheet_logo.dart
- share_sheet_example.dart
- @immutable
- route_test.dart
- package:flutter/material.dart
- slide_vs_shrink_recipe.dart
- ios26.json
- ios27.json
- Master state
- observed_profiles.dart
- package:stupid_simple_sheet/stupid_simple_sheet.dart
- snapping_recipe.dart
- Simple Stupid iOS Sheet
- Flutter engine and opaque API
- package:flutter/cupertino.dart
- glass_sheet_preset.dart
- programmatic_control_recipe.dart
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
- content_sized_above_keyboard.dart
- flutter/README.md

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

## Communities (62 total, 15 thin omitted)

### Community 0 - "stupid_simple_sheet.dart"
Cohesion: 0.03
Nodes (74): Duration get, allowSnapshotting, animateToRelative, animation, _animationTargetValue, backgroundSnapshotController, backgroundSnapshotMode, barrierColor (+66 more)

### Community 1 - "route.dart"
Cohesion: 0.03
Nodes (64): _animationChanged, _attach, backgroundColor, barrierColor, barrierDismissible, barrierLabel, buildContent, buildModalBarrier (+56 more)

### Community 2 - "example_card.dart"
Cohesion: 0.04
Nodes (47): borderColor, borderRadius, build, _buildFooter, _buildPreview, _cardRandom, CardSection, categoryId (+39 more)

### Community 3 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.17
Nodes (11): dart:convert, main, environment, main, base, main, main, package:flutter_test/flutter_test.dart (+3 more)

### Community 4 - "sheet_previews.dart"
Cohesion: 0.07
Nodes (29): CustomPainter, _RulerPainter, _InnerShadowPainter, _SheetLogoPainter, build, child, color, DashedLinePainter (+21 more)

### Community 5 - "candidate/lib/main.dart"
Cohesion: 0.05
Nodes (37): ChangeNotifier, dart:async, _active, _backgroundTouches, _beginTrace, build, _content, controller (+29 more)

### Community 6 - "profile.dart"
Cohesion: 0.05
Nodes (36): bottomInset, boundaryPoints, copyWith, cornerRadius, detentToVisibleHeight, dragResistance, environment, evidence (+28 more)

### Community 7 - "shrink_transition.dart"
Cohesion: 0.05
Nodes (42): Animation, AnimationWithParentMixin, @internal, class RenderShrinkTransition extends, dart:math, double get, clamped, ClampedAnimation (+34 more)

### Community 8 - "CHANGELOG.md"
Cohesion: 0.06
Nodes (35): 0.0.2, 0.0.2-dev.0+1, 0.0.2-dev.1, 0.0.2-dev.2, 0.3.0, 0.3.0+1, 0.3.0-dev.0, 0.3.0-dev.1 (+27 more)

### Community 9 - "sheet_background.dart"
Cohesion: 0.08
Nodes (24): Clip, double?, build, child, clipBehavior, OptimizedClip, shape, backgroundColor (+16 more)

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
Cohesion: 0.06
Nodes (30): advanced/custom_route_example.dart, advanced/dynamic_content_example.dart, advanced/share_sheet_example.dart, _advancedCards, build, _cardMaxWidth, _cardSection, _cardSpacing (+22 more)

### Community 14 - "snapping_point.dart"
Cohesion: 0.08
Nodes (29): @Deprecated, _LargestSnapPhysics, AbsoluteSnapPhysics, constantDeceleration, dragCoefficient, findClosestPoint, findClosestSnapPoint, findTargetSnapPoint (+21 more)

### Community 15 - "stupid_simple_cupertino_sheet.dart"
Cohesion: 0.07
Nodes (29): DelegatedTransitionBuilder? get, backgroundColor, backgroundSnapshotMode, barrierColor, barrierDismissible, barrierLabel, buildContent, buildTransitions (+21 more)

### Community 16 - "_"
Cohesion: 0.07
Nodes (27): EdgeInsets, _, availableSize, contentHeight, custom, _DetentKind, displayScale, fraction (+19 more)

### Community 17 - "playground_page.dart"
Cohesion: 0.05
Nodes (40): _clock, event, frame, IosSheetTraceRecorder, metrics, runId, _sequence, sink (+32 more)

### Community 18 - ".application"
Cohesion: 0.10
Nodes (15): Any, Bool, Darwin, Flutter, AppDelegate, SceneDelegate, RunnerTests, FlutterAppDelegate (+7 more)

### Community 19 - "custom_route_example.dart"
Cohesion: 0.06
Nodes (35): Color? get, DismissalMode get, _addItem, barrierColor, barrierDismissible, barrierLabel, build, buildContent (+27 more)

### Community 20 - "Cookbook"
Cohesion: 0.11
Nodes (17): Background snapshotting, Cookbook, Cupertino sheet, Custom routes (maximum control), Customizing preset routes, Glass sheet (iOS 26), Important, Installation (+9 more)

### Community 21 - "package:stupid_simple_sheet_example/widgets/example_theme.dart"
Cohesion: 0.22
Nodes (8): BasicSheetPreview, build, showBasicSheet, build, showStickyFooterSheet, StickyFooterPreview, package:stupid_simple_sheet_example/widgets/example_theme.dart, package:stupid_simple_sheet_example/widgets/sheet_previews.dart

### Community 22 - "StatelessWidget"
Cohesion: 0.13
Nodes (15): CalibrationContent, IosSheetCandidateApp, _CardGrid, _HomePage, _SubsectionLabel, _OpenButton, _OptionRow, PlaygroundPreview (+7 more)

### Community 23 - "stupid_simple_sheet_test.dart"
Cohesion: 0.15
Nodes (12): AssertionError, basedir, compare, findTargetSnapPoint, _maxPixelMismatchCount, PixelDiffGoldenComparator, target, _testBaseDirectory (+4 more)

### Community 24 - "non_draggable.dart"
Cohesion: 0.16
Nodes (22): bool get, StupidSimpleIosSheetRoute, CustomSheetRoute, build, _canPop, createState, _CustomDraggabilityRoute, dispose (+14 more)

### Community 25 - "sheet_logo.dart"
Cohesion: 0.18
Nodes (10): Color?, dart:ui, build, deviceColor, gestureColor, paint, sheetColor, SheetLogo (+2 more)

### Community 26 - "share_sheet_example.dart"
Cohesion: 0.20
Nodes (9): build, color, _Contact, _contacts, initials, name, ShareSheetExample, ShareSheetPreview (+1 more)

### Community 27 - "@immutable"
Cohesion: 0.20
Nodes (10): @immutable, IosSheetDetent, IosSheetEnvironment, ResolvedIosDetent, IosSheetGeometry, IosSheetGeometryContext, IosSheetProfile, IosSheetResistanceContext (+2 more)

### Community 28 - "route_test.dart"
Cohesion: 0.22
Nodes (8): backgroundTaps, controller, findTargetSnapPoint, main, navigator, present, GlobalKey, NavigatorState

### Community 29 - "package:flutter/material.dart"
Cohesion: 0.25
Nodes (6): dart:io, main, main, package:flutter/material.dart, package:snaptest/snaptest.dart, package:stupid_simple_sheet_example/widgets/sheet_logo.dart

### Community 30 - "slide_vs_shrink_recipe.dart"
Cohesion: 0.40
Nodes (4): build, _show, SlideVsShrinkPreview, SlideVsShrinkRecipe

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

### Community 35 - "package:stupid_simple_sheet/stupid_simple_sheet.dart"
Cohesion: 0.29
Nodes (6): package:stupid_simple_sheet/stupid_simple_sheet.dart, src/detents.dart, src/observed_profiles.dart, src/profile.dart, src/route.dart, src/trace.dart

### Community 36 - "snapping_recipe.dart"
Cohesion: 0.33
Nodes (5): build, _colorForStop, showSnappingSheet, SnappingPreview, snaps

### Community 37 - "Simple Stupid iOS Sheet"
Cohesion: 0.33
Nodes (5): Evidence policy, Repository layout, Simple Stupid iOS Sheet, Status, Upstream

### Community 38 - "Flutter engine and opaque API"
Cohesion: 0.40
Nodes (4): Architecture map, Flutter engine and opaque API, Profile discipline, Public capability scope

### Community 39 - "package:flutter/cupertino.dart"
Cohesion: 0.29
Nodes (5): build, ContentSizedPreview, showContentSizedSheet, RouteSnapshotMode, package:flutter/cupertino.dart

### Community 40 - "glass_sheet_preset.dart"
Cohesion: 0.40
Nodes (4): build, GlassSheetPreset, GlassSheetPreview, _push

### Community 41 - "programmatic_control_recipe.dart"
Cohesion: 0.40
Nodes (4): build, _ControlPanel, ProgrammaticControlPreview, showProgrammaticControlSheet

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
Cohesion: 0.33
Nodes (5): Brother 2 — Flutter engine milestone, Changed areas, Conclusions, Runtime proof and tests, Uncertainty / blockers / next decision

### Community 60 - "content_sized_above_keyboard.dart"
Cohesion: 0.40
Nodes (4): build, _Content, ContentSizedKeyboardPreview, showContentSizedKeyboardSheet

## Knowledge Gaps
- **642 isolated node(s):** `Darwin`, `XCTest`, `_metadata`, `_major`, `_undimmed` (+637 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 754 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `_`, `sheet_logo.dart`, `playground_page.dart`, `package:flutter/cupertino.dart`?**
  _High betweenness centrality (0.058) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `package:flutter_test/flutter_test.dart`, `sheet_background.dart`, `observed_profiles.dart`, `@immutable`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `SheetSnappingConfig` connect `@immutable` to `stupid_simple_sheet.dart`, `stupid_simple_glass_sheet.dart`, `snapping_point.dart`, `stupid_simple_cupertino_sheet.dart`, `custom_route_example.dart`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **What connects `Darwin`, `XCTest`, `_metadata` to the rest of the system?**
  _642 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `stupid_simple_sheet.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02666666666666667 - nodes in this community are weakly interconnected._
- **Should `route.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.03076923076923077 - nodes in this community are weakly interconnected._
- **Should `example_card.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.04251700680272109 - nodes in this community are weakly interconnected._