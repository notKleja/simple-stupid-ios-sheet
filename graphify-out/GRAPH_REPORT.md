# Graph Report - flutter-engine  (2026-10-06)

## Corpus Check
- 166 files · ~226,514 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 268 file(s) not represented in the graph (top: .gz 242, (none) 8, .plist 5)

## Summary
- 1828 nodes · 2681 edges · 128 communities (101 shown, 27 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 26 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e16fbddd`
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
- clamped_animation.dart
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
- argparse
- StatelessWidget
- .application
- custom_route_example.dart
- trace.dart
- Cookbook
- sheet_background.dart
- timing_v2_ios26_attempt1/manifest.json
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
- timing_v2_ios27_attempt1/manifest.json
- properties
- observed_profiles.dart
- simple_stupid_ios_sheet.dart
- Brother 2 — Flutter engine milestone
- shrink_transition.dart
- Flutter engine and opaque API
- example
- contract_v2_pair/README.md
- flutter/README.md
- LaunchImage.imageset/README.md
- Runner-Bridging-Header.h
- candidate/README.md
- flutter_reference/CONTRACT_V2.md
- sheet_dismissal_transition.dart
- sheet_constants.dart
- UPSTREAM.md
- double?
- int?
- String?
- ios27_0_v2_timing_reference_attempt2/manifest.json
- ios27_0_v2_timing_reference/manifest.json
- form_ipad_preferred_320x320
- snap_physics_test.dart
- form_ipad_preferred_320x320
- large_rest
- medium_rest
- large_rest
- medium_rest
- detents
- page_phone_402x874
- detents
- page_phone_402x874
- CustomPainter
- Native iOS sheet parity report
- safe_area
- analyze_timing.py
- page_ipad_834x1210
- page_vphone_430x932
- page_ipad_834x1210
- safe_area
- Phase 2 timing diagnostic
- fixture
- replay_timing.dart
- replay_timing_test.dart
- CardSection

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
10. `compare()` - 14 edges

## Surprising Connections (you probably didn't know these)
- `main()` --calls--> `schema_equal()`  [INFERRED]
  flutter_reference/candidate/scripts/analyze_timing.py → analysis/compare.py
- `main()` --calls--> `compare()`  [INFERRED]
  flutter_reference/candidate/scripts/analyze_timing.py → analysis/compare.py
- `inventory()` --calls--> `read_jsonl()`  [INFERRED]
  flutter_reference/candidate/scripts/analyze_timing.py → analysis/compare.py
- `main()` --calls--> `read()`  [INFERRED]
  flutter_reference/candidate/scripts/bind_reference.py → native_reference/scripts/evidence_contract.py
- `main()` --calls--> `validate_cohort()`  [INFERRED]
  flutter_reference/candidate/scripts/bind_reference.py → native_reference/scripts/evidence_contract.py

## Import Cycles
- None detected.

## Communities (128 total, 27 thin omitted)

### Community 0 - "compare.py"
Cohesion: 0.12
Nodes (45): compare(), transitions(), finite(), indexed_events(), interpolate(), main(), metric_report(), First sample of final continuously in-band suffix; no unseen dwell inferred. (+37 more)

### Community 1 - "ComparisonTests"
Cohesion: 0.08
Nodes (12): ComparisonTests, config(), full_config(), full_trace(), Synthetic provenance-marker simulation for eligibility-gate tests only., trace(), InspectTests, complete_matrix() (+4 more)

### Community 2 - "properties"
Cohesion: 0.04
Nodes (45): enum, minimum, type, type, const, items, type, type (+37 more)

### Community 3 - "json"
Cohesion: 0.22
Nodes (15): Synthetic mathematics fixtures only; no fixture is a native measurement., Synthetic model fits; these do not establish an Apple spring., Test ingestion QC against labeled synthetic samples., Coverage tests contain only synthetic trace pairs; no runtime acceptance claims., Synthetic scaled-container geometry, never Apple measurements., copy, Bind unchanged native baseline attempts; QC is not motion acceptance., json (+7 more)

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
Cohesion: 0.20
Nodes (9): major_version, observed_animation_objects, platform, runtime_builds, $schema, schema_version, scope, status (+1 more)

### Community 10 - "ios27.json"
Cohesion: 0.20
Nodes (9): major_version, observed_animation_objects, platform, runtime_builds, $schema, schema_version, scope, status (+1 more)

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
Cohesion: 0.21
Nodes (17): main(), sha(), adapt_legacy(), canonical_id(), finite(), identity(), Native acceptance controls; legacy adaptation never rewrites hashed sources., read() (+9 more)

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

### Community 36 - "clamped_animation.dart"
Cohesion: 0.15
Nodes (17): Animation, AnimationWithParentMixin, @internal, double get, clamped, ClampedAnimation, ClampedAnimationX, end (+9 more)

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
Cohesion: 0.08
Nodes (28): build, GlassSheetPreset, GlassSheetPreview, _push, BasicSheetPreview, build, build, ContentSizedPreview (+20 more)

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
Cohesion: 0.06
Nodes (32): _active, _backgroundTouches, _beginTrace, build, _content, controller, createState, _detentList (+24 more)

### Community 50 - "profile.dart"
Cohesion: 0.05
Nodes (36): bottomInset, boundaryPoints, copyWith, cornerRadius, detentToVisibleHeight, dragResistance, environment, evidence (+28 more)

### Community 51 - "example_card.dart"
Cohesion: 0.06
Nodes (31): borderColor, borderRadius, build, _buildFooter, _buildPreview, _cardRandom, categoryId, codeHint (+23 more)

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
Cohesion: 0.11
Nodes (18): constantDeceleration, dragCoefficient, findClosestPoint, findClosestSnapPoint, findTargetSnapPoint, full, getAllPoints, hashCode (+10 more)

### Community 59 - "sheet_previews.dart"
Cohesion: 0.09
Nodes (22): build, child, color, dashWidth, dotColor, dotRadius, fractions, gapWidth (+14 more)

### Community 60 - "_"
Cohesion: 0.07
Nodes (27): EdgeInsets, _, availableSize, contentHeight, custom, _DetentKind, displayScale, fraction (+19 more)

### Community 61 - "playground_page.dart"
Cohesion: 0.08
Nodes (23): accentColor, _barrierDismissible, build, createState, _dismissalMode, _draggable, _initialSnap, interactive (+15 more)

### Community 62 - "argparse"
Cohesion: 0.10
Nodes (21): argparse, base64, main(), Archive fresh runtime bytes, including incomplete attempts; never synthesize…, sim(), gzip, hashlib, Locate the known red footer in compositor pixels, independent of CALayer… (+13 more)

### Community 63 - "StatelessWidget"
Cohesion: 0.10
Nodes (19): CalibrationContent, IosSheetCandidateApp, _CardGrid, _HomePage, _SubsectionLabel, _OpenButton, _OptionRow, PlaygroundPreview (+11 more)

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
Cohesion: 0.09
Nodes (23): Clip, build, child, clipBehavior, shape, backgroundColor, build, child (+15 more)

### Community 69 - "timing_v2_ios26_attempt1/manifest.json"
Cohesion: 0.07
Nodes (29): artifacts, attempt, build_mode, candidate_source_sha256, flutter_reference/candidate/lib/main.dart, flutter_reference/candidate/lib/replay_timing.dart, complete, executable_sha256 (+21 more)

### Community 70 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.17
Nodes (11): dart:convert, main, environment, main, base, main, main, package:flutter_test/flutter_test.dart (+3 more)

### Community 71 - "stupid_simple_sheet_test.dart"
Cohesion: 0.08
Nodes (22): AssertionError, dart:io, main, buildApp, isSnapshotting, main, motion, main (+14 more)

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
Cohesion: 0.34
Nodes (14): StupidSimpleIosSheetRoute, CustomSheetRoute, _openSheet, showBasicSheet, showContentSizedSheet, showStickyFooterSheet, StupidSimpleCupertinoSheetRoute, StupidSimpleGlassSheetRoute (+6 more)

### Community 78 - "State"
Cohesion: 0.17
Nodes (16): SheetPlayground, _SheetPlaygroundState, CustomRouteExample, _CustomRouteExampleState, DynamicContentExample, _DynamicContentExampleState, PlaygroundPage, _PlaygroundPageState (+8 more)

### Community 79 - "dynamic_content_example.dart"
Cohesion: 0.20
Nodes (9): _addItem, build, createState, dispose, DynamicContentPreview, focusNode, items, textController (+1 more)

### Community 80 - "share_sheet_example.dart"
Cohesion: 0.20
Nodes (9): build, color, _Contact, _contacts, initials, name, ShareSheetExample, ShareSheetPreview (+1 more)

### Community 81 - "route_test.dart"
Cohesion: 0.18
Nodes (10): ChangeNotifier, IosSheetController, backgroundTaps, controller, findTargetSnapPoint, main, navigator, present (+2 more)

### Community 82 - "timing_v2_ios27_attempt1/manifest.json"
Cohesion: 0.07
Nodes (29): artifacts, attempt, build_mode, candidate_source_sha256, flutter_reference/candidate/lib/main.dart, flutter_reference/candidate/lib/replay_timing.dart, complete, executable_sha256 (+21 more)

### Community 83 - "properties"
Cohesion: 0.08
Nodes (26): type, minimum, type, type, const, type, properties, major_version (+18 more)

### Community 84 - "observed_profiles.dart"
Cohesion: 0.29
Nodes (6): detents.dart, copyWith, fallback, observedPage402x874Profile, requireScope, profile.dart

### Community 85 - "simple_stupid_ios_sheet.dart"
Cohesion: 0.29
Nodes (6): src/comparison_contract.dart, src/detents.dart, src/observed_profiles.dart, src/profile.dart, src/route.dart, src/trace.dart

### Community 86 - "Brother 2 — Flutter engine milestone"
Cohesion: 0.29
Nodes (6): Brother 2 — Flutter engine milestone, Changed areas, Conclusions, Review round 1, Runtime proof and tests, Uncertainty / blockers / next decision

### Community 87 - "shrink_transition.dart"
Cohesion: 0.12
Nodes (17): class RenderShrinkTransition extends, createRenderObject, hitTestChildren, _illegallyComputeMinIntrinsicHeight, paint, performLayout, referenceHeight, referenceHeightOf (+9 more)

### Community 88 - "Flutter engine and opaque API"
Cohesion: 0.40
Nodes (4): Architecture map, Flutter engine and opaque API, Profile discipline, Public capability scope

### Community 89 - "example"
Cohesion: 0.40
Nodes (4): Assets, example, Getting Started, Localization

### Community 96 - "sheet_dismissal_transition.dart"
Cohesion: 0.17
Nodes (10): dart:math, DismissalMode, animation, build, child, dismissalMode, referenceHeightOf, SheetDismissalTransition (+2 more)

### Community 102 - "ios27_0_v2_timing_reference_attempt2/manifest.json"
Cohesion: 0.12
Nodes (16): artifacts, attempt, executable_sha256, motion_accepted, proof_scope, quality, scope, verdict (+8 more)

### Community 103 - "ios27_0_v2_timing_reference/manifest.json"
Cohesion: 0.12
Nodes (16): artifacts, attempt, executable_sha256, motion_accepted, proof_scope, quality, reason, verdict (+8 more)

### Community 104 - "form_ipad_preferred_320x320"
Cohesion: 0.13
Nodes (17): device, evidence_ids, device, evidence_ids, os_version, placement, preferred_content_size, scenario (+9 more)

### Community 105 - "snap_physics_test.dart"
Cohesion: 0.18
Nodes (11): @Deprecated, _LargestSnapPhysics, AbsoluteSnapPhysics, FlingSnapPhysics, FrictionSnapPhysics, LegacySnapPhysics, RelativeSnapPhysics, SnapPhysics (+3 more)

### Community 106 - "form_ipad_preferred_320x320"
Cohesion: 0.22
Nodes (9): device, evidence_ids, os_version, preferred_content_size, scenario, height, width, profiles (+1 more)

### Community 107 - "large_rest"
Cohesion: 0.53
Nodes (9): large_rest, bottom_inset, visible_height, width, x, y, large_rest, large_rest (+1 more)

### Community 108 - "medium_rest"
Cohesion: 0.53
Nodes (9): medium_rest, bottom_inset, visible_height, width, x, y, medium_rest, medium_rest (+1 more)

### Community 109 - "large_rest"
Cohesion: 0.50
Nodes (9): large_rest, large_rest, bottom_inset, visible_height, width, x, y, large_rest (+1 more)

### Community 110 - "medium_rest"
Cohesion: 0.50
Nodes (9): medium_rest, medium_rest, bottom_inset, visible_height, width, x, y, medium_rest (+1 more)

### Community 111 - "detents"
Cohesion: 0.57
Nodes (8): large, maximum, medium, medium_ratio_to_maximum, detents, detents, detents, detents

### Community 112 - "page_phone_402x874"
Cohesion: 0.25
Nodes (8): device, evidence_ids, floating_scale, os_version, scale, scenario, visible_medium_height, page_phone_402x874

### Community 113 - "detents"
Cohesion: 0.57
Nodes (8): large, maximum, medium, medium_ratio_to_maximum, detents, detents, detents, detents

### Community 114 - "page_phone_402x874"
Cohesion: 0.25
Nodes (8): device, evidence_ids, floating_scale, os_version, scale, scenario, visible_medium_height, page_phone_402x874

### Community 115 - "CustomPainter"
Cohesion: 0.29
Nodes (7): CustomPainter, _RulerPainter, _InnerShadowPainter, _SheetLogoPainter, DashedLinePainter, DotGridPainter, LineGridPainter

### Community 116 - "Native iOS sheet parity report"
Cohesion: 0.29
Nodes (6): Acceptance classification, Delivered and verified, Exact matches established, Known failures and unresolved coverage, Measured platform differences, Native iOS sheet parity report

### Community 117 - "safe_area"
Cohesion: 0.57
Nodes (7): safe_area, safe_area, safe_area, bottom, left, right, top

### Community 118 - "analyze_timing.py"
Cohesion: 0.53
Nodes (5): coverage(), digest(), inventory(), main(), Report unchanged comparator results plus honest, observed phase coverage.

### Community 119 - "page_ipad_834x1210"
Cohesion: 0.33
Nodes (6): device, evidence_ids, os_version, scale, scenario, page_ipad_834x1210

### Community 120 - "page_vphone_430x932"
Cohesion: 0.33
Nodes (6): device, evidence_ids, os_version, scale, scenario, page_vphone_430x932

### Community 121 - "page_ipad_834x1210"
Cohesion: 0.33
Nodes (6): device, evidence_ids, os_version, scale, scenario, page_ipad_834x1210

### Community 122 - "safe_area"
Cohesion: 0.53
Nodes (6): safe_area, safe_area, bottom, left, right, top

### Community 123 - "Phase 2 timing diagnostic"
Cohesion: 0.40
Nodes (4): Corrections and boundary audit, Evidence and unresolved decisions, Phase 2 timing diagnostic, Pre-correction strict results

### Community 125 - "replay_timing.dart"
Cohesion: 0.50
Nodes (3): dart:async, ProgrammaticReplay, run

### Community 126 - "replay_timing_test.dart"
Cohesion: 0.50
Nodes (3): main, package:fake_async/fake_async.dart, package:ios_sheet_candidate/replay_timing.dart

## Knowledge Gaps
- **948 isolated node(s):** `schema_version`, `proof_scope`, `split`, `attempt`, `udid` (+943 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1142 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **27 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `package:flutter/cupertino.dart`, `section_header.dart`, `_`, `playground_page.dart`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `@immutable`, `observed_profiles.dart`, `package:flutter_test/flutter_test.dart`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `schema_version`, `proof_scope`, `split` to the rest of the system?**
  _948 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `compare.py` be split into smaller, more focused modules?**
  _Cohesion score 0.11591836734693878 - nodes in this community are weakly interconnected._
- **Should `ComparisonTests` be split into smaller, more focused modules?**
  _Cohesion score 0.0818452380952381 - nodes in this community are weakly interconnected._
- **Should `properties` be split into smaller, more focused modules?**
  _Cohesion score 0.044444444444444446 - nodes in this community are weakly interconnected._
- **Should `trace.schema.json` be split into smaller, more focused modules?**
  _Cohesion score 0.04541062801932367 - nodes in this community are weakly interconnected._