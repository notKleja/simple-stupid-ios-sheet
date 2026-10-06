# Graph Report - flutter-engine  (2026-10-06)

## Corpus Check
- 150 files · ~177,427 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 228 file(s) not represented in the graph (top: .gz 202, (none) 8, .plist 5)

## Summary
- 1544 nodes · 2282 edges · 102 communities (76 shown, 26 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a987cc94`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- compare.py
- ComparisonTests
- properties
- json
- trace.schema.json
- route.dart
- stupid_simple_sheet.dart
- properties
- evidence.schema.json
- ios26.json
- ios27.json
- Master state
- Measurement + parity handoff
- EvidenceTests
- Simple Stupid iOS Sheet
- FitTests
- Harness
- evidence.json
- canonicalDetentID
- evidence_contract.py
- Native iOS Sheet Parity Design
- .record
- Third-party notices
- Trace analysis
- artifacts/README.md
- docs/README.md
- flutter_reference/README.md
- CONTRACT.md
- measurement/README.md
- ProbeWindow
- App.swift
- type
- native_reference/README.md
- DIFF_26_27.md
- Review Focus
- CalibrationView
- shrink_transition.dart
- items
- SwiftUIReference
- Native reference milestone
- package:flutter/cupertino.dart
- id
- samples
- stddev
- trials
- ios
- unit
- build.sh
- package_device.sh
- candidate/lib/main.dart
- profile.dart
- example_card.dart
- CHANGELOG.md
- _
- cupertino_sheet_copy.dart
- stupid_simple_glass_sheet.dart
- example/lib/main.dart
- stupid_simple_cupertino_sheet.dart
- snapping_point.dart
- sheet_previews.dart
- _
- playground_page.dart
- vphone_run.py
- StatelessWidget
- .application
- custom_route_example.dart
- trace.dart
- Cookbook
- sheet_background.dart
- regression.py
- package:flutter_test/flutter_test.dart
- stupid_simple_sheet_test.dart
- non_draggable.dart
- section_header.dart
- @immutable
- sheet_logo.dart
- comparison_contract.dart
- StupidSimpleSheetRoute
- State
- dynamic_content_example.dart
- share_sheet_example.dart
- route_test.dart
- Widget
- package:flutter/material.dart
- observed_profiles.dart
- simple_stupid_ios_sheet.dart
- Brother 2 — Flutter engine milestone
- route_snapshot_mode_test.dart
- Flutter engine and opaque API
- example
- contract_v2_pair/README.md
- flutter/README.md
- LaunchImage.imageset/README.md
- Runner-Bridging-Header.h
- candidate/README.md
- flutter_reference/CONTRACT_V2.md
- DismissalMode
- sheet_constants.dart
- UPSTREAM.md
- double?
- int?
- String?

## God Nodes (most connected - your core abstractions)
1. `_` - 40 edges
2. `ComparisonTests` - 37 edges
3. `trace()` - 33 edges
4. `_` - 33 edges
5. `Harness` - 26 edges
6. `require()` - 22 edges
7. `EvidenceTests` - 21 edges
8. `RegressionTests` - 16 edges
9. `finite()` - 14 edges
10. `StupidSimpleSheetRoute` - 14 edges

## Surprising Connections (you probably didn't know these)
- `run()` --uses--> `TraceError`  [INFERRED]
  analysis/regression.py → analysis/compare.py
- `main` --navigates--> `StupidSimpleIosSheetRoute`  [EXTRACTED]
  flutter_reference/packages/ios_sheet/test/route_test.dart → flutter_reference/packages/ios_sheet/lib/src/route.dart
- `_openSheet` --navigates--> `StupidSimpleSheetRoute`  [EXTRACTED]
  flutter_reference/packages/stupid_simple_sheet/example/lib/playground/playground_page.dart → flutter_reference/packages/stupid_simple_sheet/lib/stupid_simple_sheet.dart
- `_push` --navigates--> `StupidSimpleCupertinoSheetRoute`  [EXTRACTED]
  flutter_reference/packages/stupid_simple_sheet/example/lib/presets/cupertino_sheet_preset.dart → flutter_reference/packages/stupid_simple_sheet/lib/src/stupid_simple_cupertino_sheet.dart
- `_push` --navigates--> `StupidSimpleGlassSheetRoute`  [EXTRACTED]
  flutter_reference/packages/stupid_simple_sheet/example/lib/presets/glass_sheet_preset.dart → flutter_reference/packages/stupid_simple_sheet/lib/src/stupid_simple_glass_sheet.dart

## Import Cycles
- None detected.

## Communities (102 total, 26 thin omitted)

### Community 0 - "compare.py"
Cohesion: 0.15
Nodes (32): finite(), metric_report(), First sample of final continuously in-band suffix; no unseen dwell inferred., Compare observed JSONL trace pairs. Standard library only; never invent samples., Validate the declarative subset used by our fixed v1 schema, not arbitrary…, read_jsonl(), repeat_noise(), require() (+24 more)

### Community 1 - "ComparisonTests"
Cohesion: 0.08
Nodes (12): ComparisonTests, config(), full_config(), full_trace(), Synthetic provenance-marker simulation for eligibility-gate tests only., trace(), InspectTests, complete_matrix() (+4 more)

### Community 2 - "properties"
Cohesion: 0.04
Nodes (45): enum, minimum, type, type, const, items, type, type (+37 more)

### Community 3 - "json"
Cohesion: 0.18
Nodes (16): Synthetic mathematics fixtures only; no fixture is a native measurement., Synthetic model fits; these do not establish an Apple spring., Test ingestion QC against labeled synthetic samples., Coverage tests contain only synthetic trace pairs; no runtime acceptance claims., fixture(), Synthetic scaled-container geometry, never Apple measurements., SpacingTests, copy (+8 more)

### Community 4 - "trace.schema.json"
Cohesion: 0.05
Nodes (45): type, allOf, $defs, nullableRect, size, exclusiveMinimum, minimum, type (+37 more)

### Community 5 - "route.dart"
Cohesion: 0.02
Nodes (80): _activePointers, _animationChanged, _attach, backgroundColor, barrierColor, barrierDismissible, barrierLabel, buildContent (+72 more)

### Community 6 - "stupid_simple_sheet.dart"
Cohesion: 0.03
Nodes (74): Duration get, allowSnapshotting, animateToRelative, animation, _animationTargetValue, backgroundSnapshotController, backgroundSnapshotMode, barrierColor (+66 more)

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

### Community 14 - "Simple Stupid iOS Sheet"
Cohesion: 0.33
Nodes (5): Evidence policy, Repository layout, Simple Stupid iOS Sheet, Status, Upstream

### Community 16 - "Harness"
Cohesion: 0.18
Nodes (9): CGFloat, Harness, .probe, Bool, URL, Notification, UIScrollView, UISheetPresentationControllerDelegate (+1 more)

### Community 17 - "evidence.json"
Cohesion: 0.50
Nodes (3): entries, $schema, schema_version

### Community 18 - "canonicalDetentID"
Cohesion: 0.13
Nodes (14): Error, Foundation, Legacy interpretation, Native recorder contract v2, Profile acceptance, canonicalDetentID(), NativeScenario, ScenarioError (+6 more)

### Community 19 - "evidence_contract.py"
Cohesion: 0.23
Nodes (16): gzip, hashlib, adapt_legacy(), canonical_id(), finite(), identity(), Native acceptance controls; legacy adaptation never rewrites hashed sources., read() (+8 more)

### Community 20 - "Native iOS Sheet Parity Design"
Cohesion: 0.12
Nodes (15): Analyzer and regression system, Delivery sequence, Evidence and profiles, Failure handling, Flutter package and candidate harness, Flutter semantic model, Intent, Measurement contracts (+7 more)

### Community 21 - ".record"
Cohesion: 0.26
Nodes (9): FileHandle, Int64, Any, Bool, Double, String, URL, Trace (+1 more)

### Community 23 - "Trace analysis"
Cohesion: 0.25
Nodes (7): Comparison formulas, Current native relationship evidence, Fitting diagnostics, Matrix and holdouts, Record validation, Tolerances and repeat noise, Trace analysis

### Community 29 - "ProbeWindow"
Cohesion: 0.12
Nodes (16): CGPoint, App, ProbeWindow, SceneDelegate, UIApplication, Set, TimeInterval, UIApplicationDelegate (+8 more)

### Community 30 - "App.swift"
Cohesion: 0.19
Nodes (15): CADisplayLink, CALayer, coherentLayerSamples(), deviceModel(), insets(), osBuild(), rect(), sampledWindowRect() (+7 more)

### Community 31 - "type"
Cohesion: 0.18
Nodes (11): items, type, type, items, type, hypotheses, limitations, run_ids (+3 more)

### Community 34 - "Review Focus"
Cohesion: 0.20
Nodes (9): Global Constraints, Native iOS Sheet Parity Integration Plan, Review Focus, Task 1: Integrate the measurement contract, Task 2: Integrate the analyzer and regression matrix, Task 3: Integrate the native reference harness, Task 4: Integrate the Flutter engine and public API, Task 5: Reconcile contracts and complete measured profiles (+1 more)

### Community 35 - "CalibrationView"
Cohesion: 0.25
Nodes (4): CGRect, CalibrationView, NSCoder, UIView

### Community 36 - "shrink_transition.dart"
Cohesion: 0.05
Nodes (43): Animation, AnimationWithParentMixin, @internal, class RenderShrinkTransition extends, dart:math, double get, clamped, ClampedAnimation (+35 more)

### Community 37 - "items"
Cohesion: 0.29
Nodes (7): items, type, items, type, required, artifacts, entries

### Community 38 - "SwiftUIReference"
Cohesion: 0.33
Nodes (5): SwiftUIReference, .body, PresentationDetent, SwiftUI, View

### Community 39 - "Native reference milestone"
Cohesion: 0.29
Nodes (6): Changed files, branch and decisions, Conclusions and measured constants, Confidence and uncertainty, Failed hypotheses worth knowing, Native reference milestone, Review fix round1

### Community 40 - "package:flutter/cupertino.dart"
Cohesion: 0.07
Nodes (33): build, CupertinoSheetPreset, CupertinoSheetPreview, _push, build, GlassSheetPreset, GlassSheetPreview, _push (+25 more)

### Community 41 - "id"
Cohesion: 0.67
Nodes (3): minLength, type, id

### Community 42 - "samples"
Cohesion: 0.67
Nodes (3): samples, minimum, type

### Community 43 - "stddev"
Cohesion: 0.67
Nodes (3): stddev, minimum, type

### Community 44 - "trials"
Cohesion: 0.67
Nodes (3): trials, minimum, type

### Community 49 - "candidate/lib/main.dart"
Cohesion: 0.05
Nodes (37): ChangeNotifier, dart:async, _active, _backgroundTouches, _beginTrace, build, _content, controller (+29 more)

### Community 50 - "profile.dart"
Cohesion: 0.05
Nodes (36): bottomInset, boundaryPoints, copyWith, cornerRadius, detentToVisibleHeight, dragResistance, environment, evidence (+28 more)

### Community 51 - "example_card.dart"
Cohesion: 0.06
Nodes (36): borderColor, borderRadius, build, _buildFooter, _buildPreview, _cardRandom, CardSection, categoryId (+28 more)

### Community 52 - "CHANGELOG.md"
Cohesion: 0.06
Nodes (35): 0.0.2, 0.0.2-dev.0+1, 0.0.2-dev.1, 0.0.2-dev.2, 0.3.0, 0.3.0+1, 0.3.0-dev.0, 0.3.0-dev.1 (+27 more)

### Community 53 - "_"
Cohesion: 0.06
Nodes (35): _, accent, accentBlue, accentGold, accentGreen, accentIndigo, accentOrange, accentPurple (+27 more)

### Community 54 - "cupertino_sheet_copy.dart"
Cohesion: 0.06
Nodes (30): Animatable, CopiedCupertinoSheetTransitions, extraPadding, fullTransition, getDeviceShape, getOverlayedChild, getRelativeTopPadding, height (+22 more)

### Community 55 - "stupid_simple_glass_sheet.dart"
Cohesion: 0.06
Nodes (31): backgroundColor, backgroundSnapshotMode, _barrierColor, barrierDismissible, barrierLabel, blurBehindBarrier, buildContent, buildModalBarrier (+23 more)

### Community 56 - "example/lib/main.dart"
Cohesion: 0.06
Nodes (30): advanced/custom_route_example.dart, advanced/dynamic_content_example.dart, advanced/share_sheet_example.dart, _advancedCards, build, _cardMaxWidth, _cardSection, _cardSpacing (+22 more)

### Community 57 - "stupid_simple_cupertino_sheet.dart"
Cohesion: 0.07
Nodes (29): DelegatedTransitionBuilder? get, backgroundColor, backgroundSnapshotMode, barrierColor, barrierDismissible, barrierLabel, buildContent, buildTransitions (+21 more)

### Community 58 - "snapping_point.dart"
Cohesion: 0.08
Nodes (27): @Deprecated, _LargestSnapPhysics, AbsoluteSnapPhysics, constantDeceleration, dragCoefficient, findClosestPoint, findClosestSnapPoint, findTargetSnapPoint (+19 more)

### Community 59 - "sheet_previews.dart"
Cohesion: 0.08
Nodes (27): CustomPainter, _RulerPainter, _InnerShadowPainter, _SheetLogoPainter, build, child, color, DashedLinePainter (+19 more)

### Community 60 - "_"
Cohesion: 0.07
Nodes (27): EdgeInsets, _, availableSize, contentHeight, custom, _DetentKind, displayScale, fraction (+19 more)

### Community 61 - "playground_page.dart"
Cohesion: 0.08
Nodes (24): accentColor, _barrierDismissible, build, createState, _dismissalMode, _draggable, _initialSnap, interactive (+16 more)

### Community 62 - "vphone_run.py"
Cohesion: 0.12
Nodes (16): argparse, base64, Locate the known red footer in compositor pixels, independent of CALayer…, main(), Run one deterministic scenario; archive only completed runtime trace batches., sim(), main(), Download only complete native research traces through the guest file API. (+8 more)

### Community 63 - "StatelessWidget"
Cohesion: 0.09
Nodes (21): CalibrationContent, IosSheetCandidateApp, _CardGrid, _HomePage, _SubsectionLabel, _OpenButton, _OptionRow, PlaygroundPreview (+13 more)

### Community 64 - ".application"
Cohesion: 0.10
Nodes (15): Darwin, Flutter, AppDelegate, Any, Bool, UIApplication, SceneDelegate, RunnerTests (+7 more)

### Community 65 - "custom_route_example.dart"
Cohesion: 0.11
Nodes (18): Color? get, DismissalMode get, _addItem, barrierColor, barrierDismissible, barrierLabel, build, buildContent (+10 more)

### Community 66 - "trace.dart"
Cohesion: 0.11
Nodes (17): comparison_contract.dart, _clock, event, eventWithProvenance, frame, implementationProvenance, IosSheetTraceRecorder, metrics (+9 more)

### Community 67 - "Cookbook"
Cohesion: 0.11
Nodes (17): Background snapshotting, Cookbook, Cupertino sheet, Custom routes (maximum control), Customizing preset routes, Glass sheet (iOS 26), Important, Installation (+9 more)

### Community 68 - "sheet_background.dart"
Cohesion: 0.12
Nodes (15): backgroundColor, build, child, clipBehavior, elevateCupertinoUserInterfaceLevel, extensionAtBottom, _getDefaultBackgroundColor, _includeSafeArea (+7 more)

### Community 69 - "regression.py"
Cohesion: 0.26
Nodes (14): compare(), transitions(), indexed_events(), interpolate(), main(), schema_equal(), cells(), entry_request() (+6 more)

### Community 70 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.17
Nodes (11): dart:convert, main, environment, main, base, main, main, package:flutter_test/flutter_test.dart (+3 more)

### Community 71 - "stupid_simple_sheet_test.dart"
Cohesion: 0.15
Nodes (12): AssertionError, basedir, compare, findTargetSnapPoint, _maxPixelMismatchCount, PixelDiffGoldenComparator, target, _testBaseDirectory (+4 more)

### Community 72 - "non_draggable.dart"
Cohesion: 0.17
Nodes (12): bool get, build, _canPop, createState, _CustomDraggabilityRoute, dispose, draggable, _draggableNotifier (+4 more)

### Community 73 - "section_header.dart"
Cohesion: 0.18
Nodes (10): Color?, build, hint, icon, iconColor, logo, SectionHeader, subtitle (+2 more)

### Community 74 - "@immutable"
Cohesion: 0.20
Nodes (10): @immutable, IosSheetDetent, IosSheetEnvironment, ResolvedIosDetent, IosSheetGeometry, IosSheetGeometryContext, IosSheetProfile, IosSheetResistanceContext (+2 more)

### Community 75 - "sheet_logo.dart"
Cohesion: 0.20
Nodes (9): dart:ui, build, deviceColor, gestureColor, paint, sheetColor, SheetLogo, shouldRepaint (+1 more)

### Community 76 - "comparison_contract.dart"
Cohesion: 0.20
Nodes (9): canonicalIosDetentIdentifier, canonicalIosSheetConfiguration, detents, iosPageReferenceConfiguration, iosSheetComparisonConfigurationKeys, largest, rawDetents, undimmed (+1 more)

### Community 77 - "StupidSimpleSheetRoute"
Cohesion: 0.60
Nodes (10): StupidSimpleIosSheetRoute, CustomSheetRoute, StupidSimpleCupertinoSheetRoute, StupidSimpleGlassSheetRoute, StupidSimpleSheetController, StupidSimpleSheetRoute, StupidSimpleSheetTransitionMixin, main (+2 more)

### Community 78 - "State"
Cohesion: 0.27
Nodes (10): CustomRouteExample, _CustomRouteExampleState, DynamicContentExample, _DynamicContentExampleState, PlaygroundPage, _PlaygroundPageState, _RelativeGestureDetector, _RelativeGestureDetectorState (+2 more)

### Community 79 - "dynamic_content_example.dart"
Cohesion: 0.20
Nodes (9): _addItem, build, createState, dispose, DynamicContentPreview, focusNode, items, textController (+1 more)

### Community 80 - "share_sheet_example.dart"
Cohesion: 0.20
Nodes (9): build, color, _Contact, _contacts, initials, name, ShareSheetExample, ShareSheetPreview (+1 more)

### Community 81 - "route_test.dart"
Cohesion: 0.22
Nodes (8): backgroundTaps, controller, findTargetSnapPoint, main, navigator, present, GlobalKey, NavigatorState

### Community 82 - "Widget"
Cohesion: 0.25
Nodes (7): Clip, build, child, clipBehavior, shape, ShapeBorder, Widget

### Community 83 - "package:flutter/material.dart"
Cohesion: 0.25
Nodes (6): dart:io, main, main, package:flutter/material.dart, package:snaptest/snaptest.dart, package:stupid_simple_sheet_example/widgets/sheet_logo.dart

### Community 84 - "observed_profiles.dart"
Cohesion: 0.29
Nodes (6): detents.dart, copyWith, fallback, observedPage402x874Profile, requireScope, profile.dart

### Community 85 - "simple_stupid_ios_sheet.dart"
Cohesion: 0.29
Nodes (6): src/comparison_contract.dart, src/detents.dart, src/observed_profiles.dart, src/profile.dart, src/route.dart, src/trace.dart

### Community 86 - "Brother 2 — Flutter engine milestone"
Cohesion: 0.29
Nodes (6): Brother 2 — Flutter engine milestone, Changed areas, Conclusions, Review round 1, Runtime proof and tests, Uncertainty / blockers / next decision

### Community 87 - "route_snapshot_mode_test.dart"
Cohesion: 0.33
Nodes (5): buildApp, isSnapshotting, main, motion, SnapshotWidget

### Community 88 - "Flutter engine and opaque API"
Cohesion: 0.40
Nodes (4): Architecture map, Flutter engine and opaque API, Profile discipline, Public capability scope

### Community 89 - "example"
Cohesion: 0.40
Nodes (4): Assets, example, Getting Started, Localization

## Knowledge Gaps
- **794 isolated node(s):** `XCTest`, `_metadata`, `_major`, `_undimmed`, `_content` (+789 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 982 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **26 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `package:flutter/cupertino.dart`, `section_header.dart`, `_`, `playground_page.dart`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `@immutable`, `observed_profiles.dart`, `package:flutter_test/flutter_test.dart`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Why does `SheetSnappingConfig` connect `@immutable` to `custom_route_example.dart`, `stupid_simple_sheet.dart`, `stupid_simple_glass_sheet.dart`, `stupid_simple_cupertino_sheet.dart`, `snapping_point.dart`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **What connects `XCTest`, `_metadata`, `_major` to the rest of the system?**
  _794 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `compare.py` be split into smaller, more focused modules?**
  _Cohesion score 0.14603174603174604 - nodes in this community are weakly interconnected._
- **Should `ComparisonTests` be split into smaller, more focused modules?**
  _Cohesion score 0.0818452380952381 - nodes in this community are weakly interconnected._
- **Should `properties` be split into smaller, more focused modules?**
  _Cohesion score 0.044444444444444446 - nodes in this community are weakly interconnected._