# Graph Report - synchronized-video  (2026-10-07)

## Corpus Check
- 260 files · ~395,394 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 533 file(s) not represented in the graph (top: .gz 507, (none) 8, .plist 5)

## Summary
- 2696 nodes · 4048 edges · 190 communities (154 shown, 36 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 67 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7fada252`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- runtime_batch.py
- ComparisonTests
- properties
- pathlib
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
- SynchronizedNativeDemoController
- evidence.json
- canonicalDetentID
- validate_interaction_cohort
- Native iOS Sheet Parity Design
- .record
- Third-party notices
- Trace analysis
- artifacts/README.md
- docs/README.md
- flutter_reference/README.md
- CONTRACT.md
- measurement/README.md
- .scene
- App.swift
- type
- native_reference/README.md
- DIFF_26_27.md
- Review Focus
- properties
- clamped_animation.dart
- items
- synchronized_demo.dart
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
- UIKit
- custom_route_example.dart
- trace.dart
- Cookbook
- sheet_background.dart
- vphone_nonmodal_delivery_failure/manifest.json
- package:flutter_test/flutter_test.dart
- stupid_simple_sheet_test.dart
- non_draggable.dart
- shrink_transition.dart
- @immutable
- sheet_logo.dart
- comparison_contract.dart
- StupidSimpleSheetRoute
- evidence_contract.py
- dynamic_content_example.dart
- record_synchronized_demo.py
- route_test.dart
- ios26_downward_attempt2/manifest.json
- form_ipad_preferred_320x320
- observed_profiles.dart
- simple_stupid_ios_sheet.dart
- Brother 2 — Flutter engine milestone
- ios26_content_first/manifest.json
- Flutter engine and opaque API
- example
- contract_v2_pair/README.md
- flutter/README.md
- LaunchImage.imageset/README.md
- Runner-Bridging-Header.h
- candidate/README.md
- flutter_reference/CONTRACT_V2.md
- Harness
- sheet_constants.dart
- UPSTREAM.md
- double?
- int?
- String?
- ios26_downward/manifest.json
- sheet_dismissal_transition.dart
- argparse
- form_ipad_preferred_320x320
- large_rest
- medium_rest
- large_rest
- medium_rest
- detents
- page_phone_402x874
- detents
- page_phone_402x874
- ios26_nonmodal_pilot/manifest.json
- ios26_expands_first/manifest.json
- Native iOS sheet parity report
- ProbeWindow
- generate_xctest_project.py
- safe_area
- ios26_strict_anchored/manifest.json
- ios27_strict_anchored/manifest.json
- page_ipad_834x1210
- page_vphone_430x932
- page_ipad_834x1210
- safe_area
- ios26_nonmodal/manifest.json
- ios27_expands_first/manifest.json
- INTERACTIONS_PLAN.md
- users_kleja_simple_stupid_ios_sheet_worktrees_flutter_engine_flutter_reference_candidate_ios_runner_generatedpluginregistrant_h
- timing_v2_ios26_attempt1/manifest.json
- configuration
- session
- device
- diagnostic_unpinned27_content/manifest.json
- diagnostic_unpinned27_expands/manifest.json
- ios27_content_first/manifest.json
- ios27_downward/manifest.json
- ios27_nonmodal/manifest.json
- environment
- diagnostic_cached26_content/manifest.json
- diagnostic_cached26_expands/manifest.json
- diagnostic_cached26_nonmodal/manifest.json
- diagnostic_unpinned27_nonmodal/manifest.json
- coalescing_diagnostic/manifest.json
- frame
- package:flutter/material.dart
- safe_area
- Native interaction evidence
- provenance
- timing_v2_ios27_attempt1/manifest.json
- TIMING_DIAGNOSIS.md
- candidate/scripts/collect_simulator.py
- fixture
- RuntimeBatchTests
- CodingKeys
- stream
- device
- 20261007-013017/manifest.json
- State
- ios27_0_v2_timing_reference_attempt2/manifest.json
- ios27_0_v2_timing_reference/manifest.json
- SynchronizedDemoScene
- validate_timeline
- visible_alignment
- acknowledgements
- Full Native Sheet Parity Continuation Design
- NativeInteractionUITests
- snap_physics_test.dart
- Review Focus
- value
- .componentContent
- .application
- Review Focus
- glass_sheet_transitions.dart
- launches
- Synchronized Bilingual Simulator Video Design
- synchronized_demo_test.dart
- timeline_summary
- Phase 2 timing diagnostic
- dart:async
- replay_timing_test.dart
- Runtime parity batch — phase 2
- .viewDidAppear
- .init
- _ExampleCardState
- 20261007-013017/README.md
- CardSection
- RUNTIME_CONTRACT.md
- generatedpluginregistrant

## God Nodes (most connected - your core abstractions)
1. `_` - 40 edges
2. `ComparisonTests` - 37 edges
3. `Harness` - 36 edges
4. `trace()` - 33 edges
5. `_` - 33 edges
6. `require()` - 31 edges
7. `SynchronizedNativeDemoController` - 29 edges
8. `CodingKeys` - 29 edges
9. `main()` - 24 edges
10. `RuntimeBatchTests` - 23 edges

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

## Communities (190 total, 36 thin omitted)

### Community 0 - "runtime_batch.py"
Cohesion: 0.08
Nodes (68): compare(), transitions(), finite(), indexed_events(), interpolate(), main(), metric_report(), ValueError (+60 more)

### Community 1 - "ComparisonTests"
Cohesion: 0.09
Nodes (10): ComparisonTests, config(), full_config(), full_trace(), Synthetic provenance-marker simulation for eligibility-gate tests only., trace(), InspectTests, complete_matrix() (+2 more)

### Community 2 - "properties"
Cohesion: 0.04
Nodes (45): enum, minimum, type, type, const, items, type, type (+37 more)

### Community 3 - "pathlib"
Cohesion: 0.17
Nodes (19): Synthetic mathematics fixtures only; no fixture is a native measurement., Synthetic model fits; these do not establish an Apple spring., Test ingestion QC against labeled synthetic samples., gate_records(), Coverage tests contain only synthetic trace pairs; no runtime acceptance claims., Explicitly synthetic records with simulated runtime markers to exercise gate…, Synthetic gate simulations only; runtime marker fixtures are not native…, Synthetic scaled-container geometry, never Apple measurements. (+11 more)

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

### Community 16 - "SynchronizedNativeDemoController"
Cohesion: 0.16
Nodes (10): CADisplayLink, Double, String, UIScrollView, UISheetPresentationController, SynchronizedNativeDemoController, UILabel, UISegmentedControl (+2 more)

### Community 17 - "evidence.json"
Cohesion: 0.50
Nodes (3): entries, $schema, schema_version

### Community 18 - "canonicalDetentID"
Cohesion: 0.15
Nodes (12): Error, Legacy interpretation, Native recorder contract v2, Profile acceptance, UISheetPresentationController, canonicalDetentID(), NativeScenario, ScenarioError (+4 more)

### Community 19 - "validate_interaction_cohort"
Cohesion: 0.23
Nodes (5): main(), Archive exact native interaction attempts and immutable source hashes., nonmodal_outcomes(), validate_interaction_cohort(), InteractionAcceptanceTests

### Community 20 - "Native iOS Sheet Parity Design"
Cohesion: 0.12
Nodes (15): Analyzer and regression system, Delivery sequence, Evidence and profiles, Failure handling, Flutter package and candidate harness, Flutter semantic model, Intent, Measurement contracts (+7 more)

### Community 21 - ".record"
Cohesion: 0.14
Nodes (13): FileHandle, Foundation, Int64, Any, Bool, Double, String, URL (+5 more)

### Community 23 - "Trace analysis"
Cohesion: 0.22
Nodes (8): Actual runtime batches, Comparison formulas, Current native relationship evidence, Fitting diagnostics, Matrix and holdouts, Record validation, Tolerances and repeat noise, Trace analysis

### Community 29 - ".scene"
Cohesion: 0.15
Nodes (12): App, SceneDelegate, UIApplication, Set, UIApplicationDelegate, UIOpenURLContext, UIResponder, UIScene (+4 more)

### Community 30 - "App.swift"
Cohesion: 0.13
Nodes (19): CALayer, CalibrationView, coherentLayerSamples(), deviceModel(), insets(), osBuild(), rect(), sampledWindowRect() (+11 more)

### Community 31 - "type"
Cohesion: 0.18
Nodes (11): items, type, type, items, type, hypotheses, limitations, run_ids (+3 more)

### Community 34 - "Review Focus"
Cohesion: 0.20
Nodes (9): Global Constraints, Native iOS Sheet Parity Integration Plan, Review Focus, Task 1: Integrate the measurement contract, Task 2: Integrate the analyzer and regression matrix, Task 3: Integrate the native reference harness, Task 4: Integrate the Flutter engine and public API, Task 5: Reconcile contracts and complete measured profiles (+1 more)

### Community 35 - "properties"
Cohesion: 0.08
Nodes (26): type, minimum, type, type, const, type, properties, major_version (+18 more)

### Community 36 - "clamped_animation.dart"
Cohesion: 0.15
Nodes (17): Animation, AnimationWithParentMixin, @internal, double get, clamped, ClampedAnimation, ClampedAnimationX, end (+9 more)

### Community 37 - "items"
Cohesion: 0.29
Nodes (7): items, type, items, type, required, artifacts, entries

### Community 38 - "synchronized_demo.dart"
Cohesion: 0.03
Nodes (59): ackDirectory, actions, actionsBetween, atMs, backgroundPulse, build, child, _completionWritten (+51 more)

### Community 39 - "Native reference milestone"
Cohesion: 0.29
Nodes (6): Changed files, branch and decisions, Conclusions and measured constants, Confidence and uncertainty, Failed hypotheses worth knowing, Native reference milestone, Review fix round1

### Community 40 - "package:flutter/cupertino.dart"
Cohesion: 0.06
Nodes (36): build, CupertinoSheetPreset, CupertinoSheetPreview, _push, build, GlassSheetPreset, GlassSheetPreview, _push (+28 more)

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
Nodes (35): ChangeNotifier, _active, _backgroundTouches, _beginTrace, build, _content, controller, createState (+27 more)

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
Cohesion: 0.08
Nodes (23): Animatable, CopiedCupertinoSheetTransitions, extraPadding, fullTransition, getDeviceShape, getOverlayedChild, getRelativeTopPadding, height (+15 more)

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
Cohesion: 0.07
Nodes (30): CustomPainter, _RulerPainter, _DemoRulerPainter, _InnerShadowPainter, _SheetLogoPainter, build, child, color (+22 more)

### Community 60 - "_"
Cohesion: 0.07
Nodes (27): EdgeInsets, _, availableSize, contentHeight, custom, _DetentKind, displayScale, fraction (+19 more)

### Community 61 - "playground_page.dart"
Cohesion: 0.08
Nodes (24): accentColor, _barrierDismissible, build, createState, _dismissalMode, _draggable, _initialSnap, interactive (+16 more)

### Community 62 - "vphone_run.py"
Cohesion: 0.17
Nodes (13): base64, Preserve bounded evidence when guest API cannot export a large failed run., main(), Download only complete native research traces through the guest file API., Capture compositor video alongside a fresh deterministic native trace batch., main(), element(), tap() (+5 more)

### Community 63 - "StatelessWidget"
Cohesion: 0.07
Nodes (27): CalibrationContent, IosSheetCandidateApp, DemoComponentGallery, DemoStage, SynchronizedDemoApp, build, color, _Contact (+19 more)

### Community 64 - "UIKit"
Cohesion: 0.10
Nodes (13): Darwin, Flutter, SceneDelegate, RunnerTests, FlutterSceneDelegate, SwiftUIReference, .body, PresentationDetent (+5 more)

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

### Community 69 - "vphone_nonmodal_delivery_failure/manifest.json"
Cohesion: 0.05
Nodes (42): device, logical_size, model, physical_size, refresh_hz, refresh_hz_source, runtime_kind, scale (+34 more)

### Community 70 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.24
Nodes (8): environment, main, base, main, main, package:flutter_test/flutter_test.dart, package:flutter/widgets.dart, package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart

### Community 71 - "stupid_simple_sheet_test.dart"
Cohesion: 0.12
Nodes (15): AssertionError, dart:io, main, basedir, compare, findTargetSnapPoint, _maxPixelMismatchCount, PixelDiffGoldenComparator (+7 more)

### Community 72 - "non_draggable.dart"
Cohesion: 0.18
Nodes (10): bool get, build, _canPop, createState, _CustomDraggabilityRoute, dispose, draggable, _draggableNotifier (+2 more)

### Community 73 - "shrink_transition.dart"
Cohesion: 0.12
Nodes (17): class RenderShrinkTransition extends, createRenderObject, hitTestChildren, _illegallyComputeMinIntrinsicHeight, paint, performLayout, referenceHeight, referenceHeightOf (+9 more)

### Community 74 - "@immutable"
Cohesion: 0.20
Nodes (10): @immutable, IosSheetDetent, IosSheetEnvironment, ResolvedIosDetent, IosSheetGeometry, IosSheetGeometryContext, IosSheetProfile, IosSheetResistanceContext (+2 more)

### Community 75 - "sheet_logo.dart"
Cohesion: 0.09
Nodes (20): Color?, dart:math, dart:ui, build, hint, icon, iconColor, logo (+12 more)

### Community 76 - "comparison_contract.dart"
Cohesion: 0.20
Nodes (9): canonicalIosDetentIdentifier, canonicalIosSheetConfiguration, detents, iosPageReferenceConfiguration, iosSheetComparisonConfigurationKeys, largest, rawDetents, undimmed (+1 more)

### Community 77 - "StupidSimpleSheetRoute"
Cohesion: 0.60
Nodes (10): StupidSimpleIosSheetRoute, CustomSheetRoute, StupidSimpleCupertinoSheetRoute, StupidSimpleGlassSheetRoute, StupidSimpleSheetController, StupidSimpleSheetRoute, StupidSimpleSheetTransitionMixin, main (+2 more)

### Community 78 - "evidence_contract.py"
Cohesion: 0.26
Nodes (13): collections, adapt_legacy(), canonical_id(), finite(), identity(), Native acceptance controls; legacy adaptation never rewrites hashed sources., require(), validate_run() (+5 more)

### Community 79 - "dynamic_content_example.dart"
Cohesion: 0.20
Nodes (9): _addItem, build, createState, dispose, DynamicContentPreview, focusNode, items, textController (+1 more)

### Community 80 - "record_synchronized_demo.py"
Cohesion: 0.11
Nodes (36): CompletedProcess, concurrent_futures, alignment_transform(), app_documents(), boot_and_install(), build_manifest(), bundled_timeline_paths(), clear_acknowledgements() (+28 more)

### Community 81 - "route_test.dart"
Cohesion: 0.22
Nodes (8): backgroundTaps, controller, findTargetSnapPoint, main, navigator, present, GlobalKey, NavigatorState

### Community 82 - "ios26_downward_attempt2/manifest.json"
Cohesion: 0.12
Nodes (15): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+7 more)

### Community 83 - "form_ipad_preferred_320x320"
Cohesion: 0.13
Nodes (17): device, evidence_ids, device, evidence_ids, os_version, placement, preferred_content_size, scenario (+9 more)

### Community 84 - "observed_profiles.dart"
Cohesion: 0.29
Nodes (6): detents.dart, copyWith, fallback, observedPage402x874Profile, requireScope, profile.dart

### Community 85 - "simple_stupid_ios_sheet.dart"
Cohesion: 0.29
Nodes (6): src/comparison_contract.dart, src/detents.dart, src/observed_profiles.dart, src/profile.dart, src/route.dart, src/trace.dart

### Community 86 - "Brother 2 — Flutter engine milestone"
Cohesion: 0.29
Nodes (6): Brother 2 — Flutter engine milestone, Changed areas, Conclusions, Review round 1, Runtime proof and tests, Uncertainty / blockers / next decision

### Community 87 - "ios26_content_first/manifest.json"
Cohesion: 0.12
Nodes (15): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+7 more)

### Community 88 - "Flutter engine and opaque API"
Cohesion: 0.40
Nodes (4): Architecture map, Flutter engine and opaque API, Profile discipline, Public capability scope

### Community 89 - "example"
Cohesion: 0.40
Nodes (4): Assets, example, Getting Started, Localization

### Community 96 - "Harness"
Cohesion: 0.08
Nodes (18): CGFloat, DispatchSourceTimer, Harness, .probe, Bool, UIScrollView, URL, InteractionProbe (+10 more)

### Community 102 - "ios26_downward/manifest.json"
Cohesion: 0.12
Nodes (15): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+7 more)

### Community 103 - "sheet_dismissal_transition.dart"
Cohesion: 0.18
Nodes (9): DismissalMode, animation, build, child, dismissalMode, referenceHeightOf, SheetDismissalTransition, package:stupid_simple_sheet/src/dismissal_mode.dart (+1 more)

### Community 104 - "argparse"
Cohesion: 0.16
Nodes (18): argparse, main(), Bind unchanged native baseline attempts; QC is not motion acceptance., sha(), gzip, hashlib, Archive final XCTest logs and observed build bytes, not a success assertion., Keep diagnostic audit bytes; never promote a single audited run. (+10 more)

### Community 105 - "form_ipad_preferred_320x320"
Cohesion: 0.22
Nodes (9): device, evidence_ids, os_version, preferred_content_size, scenario, height, width, profiles (+1 more)

### Community 106 - "large_rest"
Cohesion: 0.53
Nodes (9): large_rest, bottom_inset, visible_height, width, x, y, large_rest, large_rest (+1 more)

### Community 107 - "medium_rest"
Cohesion: 0.53
Nodes (9): medium_rest, bottom_inset, visible_height, width, x, y, medium_rest, medium_rest (+1 more)

### Community 108 - "large_rest"
Cohesion: 0.50
Nodes (9): large_rest, large_rest, bottom_inset, visible_height, width, x, y, large_rest (+1 more)

### Community 109 - "medium_rest"
Cohesion: 0.50
Nodes (9): medium_rest, medium_rest, bottom_inset, visible_height, width, x, y, medium_rest (+1 more)

### Community 110 - "detents"
Cohesion: 0.57
Nodes (8): large, maximum, medium, medium_ratio_to_maximum, detents, detents, detents, detents

### Community 111 - "page_phone_402x874"
Cohesion: 0.25
Nodes (8): device, evidence_ids, floating_scale, os_version, scale, scenario, visible_medium_height, page_phone_402x874

### Community 112 - "detents"
Cohesion: 0.57
Nodes (8): large, maximum, medium, medium_ratio_to_maximum, detents, detents, detents, detents

### Community 113 - "page_phone_402x874"
Cohesion: 0.25
Nodes (8): device, evidence_ids, floating_scale, os_version, scale, scenario, visible_medium_height, page_phone_402x874

### Community 114 - "ios26_nonmodal_pilot/manifest.json"
Cohesion: 0.29
Nodes (6): collection_revision, entries, limitations, scenario_id, schema_version, status

### Community 115 - "ios26_expands_first/manifest.json"
Cohesion: 0.12
Nodes (15): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+7 more)

### Community 116 - "Native iOS sheet parity report"
Cohesion: 0.29
Nodes (6): Acceptance classification, Delivered and verified, Exact matches established, Known failures and unresolved coverage, Measured platform differences, Native iOS sheet parity report

### Community 117 - "ProbeWindow"
Cohesion: 0.22
Nodes (7): DispatchTime, ProbeWindow, CGPoint, UITouch, TimeInterval, UIEvent, Void

### Community 118 - "generate_xctest_project.py"
Cohesion: 0.33
Nodes (5): add(), configurations(), legacy_types(), Generate only reproducible Xcode scaffolding under ignored build/., plistlib

### Community 119 - "safe_area"
Cohesion: 0.57
Nodes (7): safe_area, safe_area, safe_area, bottom, left, right, top

### Community 120 - "ios26_strict_anchored/manifest.json"
Cohesion: 0.22
Nodes (8): entries, limitations, request_ms, scenario_id, scheduler, schema_version, source_revision, status

### Community 121 - "ios27_strict_anchored/manifest.json"
Cohesion: 0.22
Nodes (8): entries, limitations, request_ms, scenario_id, scheduler, schema_version, source_revision, status

### Community 122 - "page_ipad_834x1210"
Cohesion: 0.33
Nodes (6): device, evidence_ids, os_version, scale, scenario, page_ipad_834x1210

### Community 123 - "page_vphone_430x932"
Cohesion: 0.33
Nodes (6): device, evidence_ids, os_version, scale, scenario, page_vphone_430x932

### Community 124 - "page_ipad_834x1210"
Cohesion: 0.33
Nodes (6): device, evidence_ids, os_version, scale, scenario, page_ipad_834x1210

### Community 125 - "safe_area"
Cohesion: 0.53
Nodes (6): safe_area, safe_area, bottom, left, right, top

### Community 126 - "ios26_nonmodal/manifest.json"
Cohesion: 0.12
Nodes (15): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+7 more)

### Community 127 - "ios27_expands_first/manifest.json"
Cohesion: 0.12
Nodes (15): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+7 more)

### Community 130 - "timing_v2_ios26_attempt1/manifest.json"
Cohesion: 0.07
Nodes (29): artifacts, attempt, build_mode, candidate_source_sha256, flutter_reference/candidate/lib/main.dart, flutter_reference/candidate/lib/replay_timing.dart, complete, executable_sha256 (+21 more)

### Community 131 - "configuration"
Cohesion: 0.12
Nodes (16): detents, edge_attached_in_compact_height, grabber, largest_undimmed, modal_in_presentation, page_sizing, placement, preferred_content_size (+8 more)

### Community 132 - "session"
Cohesion: 0.15
Nodes (13): build, version, session, evidence_kind, implementation, native_contract_version, os, run_id (+5 more)

### Community 133 - "device"
Cohesion: 0.17
Nodes (12): logical_size, model, physical_size, refresh_hz, refresh_hz_source, runtime_kind, scale, height (+4 more)

### Community 134 - "diagnostic_unpinned27_content/manifest.json"
Cohesion: 0.18
Nodes (10): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+2 more)

### Community 135 - "diagnostic_unpinned27_expands/manifest.json"
Cohesion: 0.18
Nodes (10): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+2 more)

### Community 136 - "ios27_content_first/manifest.json"
Cohesion: 0.18
Nodes (10): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+2 more)

### Community 137 - "ios27_downward/manifest.json"
Cohesion: 0.18
Nodes (10): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+2 more)

### Community 138 - "ios27_nonmodal/manifest.json"
Cohesion: 0.18
Nodes (10): acceptance_scope, collection_revision, entries, full_trajectory_acceptance, issues, limitations, requested_status, scenario_id (+2 more)

### Community 139 - "environment"
Cohesion: 0.18
Nodes (11): orientation, size_classes, status_bar, system_settings, environment, horizontal, vertical, hidden (+3 more)

### Community 140 - "diagnostic_cached26_content/manifest.json"
Cohesion: 0.22
Nodes (8): collection_revision, entries, issues, limitations, requested_status, scenario_id, schema_version, status

### Community 141 - "diagnostic_cached26_expands/manifest.json"
Cohesion: 0.22
Nodes (8): collection_revision, entries, issues, limitations, requested_status, scenario_id, schema_version, status

### Community 142 - "diagnostic_cached26_nonmodal/manifest.json"
Cohesion: 0.22
Nodes (8): collection_revision, entries, issues, limitations, requested_status, scenario_id, schema_version, status

### Community 143 - "diagnostic_unpinned27_nonmodal/manifest.json"
Cohesion: 0.22
Nodes (8): collection_revision, entries, issues, limitations, requested_status, scenario_id, schema_version, status

### Community 144 - "coalescing_diagnostic/manifest.json"
Cohesion: 0.25
Nodes (7): audits, limitations, path, raw_sha256, schema_version, sha256, status

### Community 145 - "frame"
Cohesion: 0.29
Nodes (7): keyboard, height, width, x, y, frame, visible

### Community 146 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (8): main, buildApp, isSnapshotting, main, motion, package:flutter/material.dart, package:ios_sheet_candidate/main.dart, SnapshotWidget

### Community 147 - "safe_area"
Cohesion: 0.40
Nodes (5): safe_area, bottom, left, right, top

### Community 148 - "Native interaction evidence"
Cohesion: 0.40
Nodes (4): Changed files, verification and next decision, Conclusions and evidence boundaries, Failed hypotheses and runtime blockers, Native interaction evidence

### Community 149 - "provenance"
Cohesion: 0.50
Nodes (4): attempt_id, native_source_revision, role, provenance

### Community 150 - "timing_v2_ios27_attempt1/manifest.json"
Cohesion: 0.07
Nodes (29): artifacts, attempt, build_mode, candidate_source_sha256, flutter_reference/candidate/lib/main.dart, flutter_reference/candidate/lib/replay_timing.dart, complete, executable_sha256 (+21 more)

### Community 152 - "candidate/scripts/collect_simulator.py"
Cohesion: 0.27
Nodes (8): main(), Archive fresh runtime bytes, including incomplete attempts; never synthesize…, sim(), main(), Run one deterministic scenario; archive only completed runtime trace batches., sim(), os, time

### Community 155 - "CodingKeys"
Cohesion: 0.08
Nodes (24): CodingKey, CodingKeys, actions, atMs, configuration, content, detent, detents (+16 more)

### Community 156 - "stream"
Cohesion: 0.11
Nodes (22): media, path, sha256, media, path, sha256, duration, size (+14 more)

### Community 157 - "device"
Cohesion: 0.14
Nodes (21): dataPath, dataPathSize, deviceTypeIdentifier, isAvailable, lastUsedAt, logPath, logPathSize, name (+13 more)

### Community 158 - "20261007-013017/manifest.json"
Cohesion: 0.10
Nodes (19): capture_base_revision, device_type, evidence_boundary, feature_source_commit, recording_start_delta_ns, recording_start_monotonic_ns, flutter, native (+11 more)

### Community 159 - "State"
Cohesion: 0.15
Nodes (19): SheetPlayground, _SheetPlaygroundState, _LiveDemo, _LiveDemoState, SynchronizedDemoBootstrap, _SynchronizedDemoBootstrapState, CustomRouteExample, _CustomRouteExampleState (+11 more)

### Community 160 - "ios27_0_v2_timing_reference_attempt2/manifest.json"
Cohesion: 0.12
Nodes (16): artifacts, attempt, executable_sha256, motion_accepted, proof_scope, quality, scope, verdict (+8 more)

### Community 161 - "ios27_0_v2_timing_reference/manifest.json"
Cohesion: 0.12
Nodes (16): artifacts, attempt, executable_sha256, motion_accepted, proof_scope, quality, reason, verdict (+8 more)

### Community 162 - "SynchronizedDemoScene"
Cohesion: 0.30
Nodes (12): Codable, scenes, Double, Int, String, SynchronizedDemoAction, SynchronizedDemoConfiguration, SynchronizedDemoScene (+4 more)

### Community 163 - "validate_timeline"
Cohesion: 0.23
Nodes (8): _integer(), main(), Any, ValueError, Validate the shared native/Flutter synchronized demo timeline., TimelineError, validate_timeline(), TimelineValidationTests

### Community 164 - "visible_alignment"
Cohesion: 0.13
Nodes (15): flutter, native, scale, start, scale, start, flutter, native (+7 more)

### Community 165 - "acknowledgements"
Cohesion: 0.15
Nodes (13): acknowledgements, flutter_armed, flutter_completed, native_armed, native_completed, path, sha256, path (+5 more)

### Community 166 - "Full Native Sheet Parity Continuation Design"
Cohesion: 0.15
Nodes (12): Acceptance and delivery, Accessibility and performance, Binding evidence rules, Correct native radius and contour model, Flutter architecture, Full Native Sheet Parity Continuation Design, Intent, Interaction and modality (+4 more)

### Community 167 - "NativeInteractionUITests"
Cohesion: 0.32
Nodes (5): NativeInteractionUITests, Double, Int, String, XCUIApplication

### Community 168 - "snap_physics_test.dart"
Cohesion: 0.18
Nodes (11): @Deprecated, _LargestSnapPhysics, AbsoluteSnapPhysics, FlingSnapPhysics, FrictionSnapPhysics, LegacySnapPhysics, RelativeSnapPhysics, SnapPhysics (+3 more)

### Community 169 - "Review Focus"
Cohesion: 0.17
Nodes (11): Full Native Sheet Parity Continuation Implementation Plan, Global Constraints, Review Focus, Task 1: Integrate completed phase-two branches, Task 2: Version scenario, condition, and applicability contracts, Task 3: Measure UIKit radii, contour, barrier, and presenter, Task 4: Measure gestures, snap decisions, interruption, and scrolling, Task 5: Measure keyboard, content, stacking, adaptivity, and accessibility (+3 more)

### Community 170 - "value"
Cohesion: 0.36
Nodes (11): value, value, value, value, duration_ms, elapsed_ms, first_scene, last_scene (+3 more)

### Community 171 - ".componentContent"
Cohesion: 0.33
Nodes (3): UIView, Bool, SynchronizedDemoPresentation

### Community 172 - ".application"
Cohesion: 0.22
Nodes (7): AppDelegate, Any, Bool, UIApplication, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate

### Community 173 - "Review Focus"
Cohesion: 0.25
Nodes (7): Global Constraints, Review Focus, Synchronized Bilingual Simulator Video Implementation Plan, Task 1: Timeline contract, Task 2: Native demo mode, Task 3: Flutter demo mode, Task 4: Dual simulator coordinator and video

### Community 174 - "glass_sheet_transitions.dart"
Cohesion: 0.25
Nodes (7): fullTransition, GlassSheetTransitions, secondarySlideDownTransition, secondarySlideUpTransition, Offset, package:stupid_simple_sheet/src/clamped_animation.dart, package:stupid_simple_sheet/src/cupertino_sheet_copy.dart

### Community 175 - "launches"
Cohesion: 0.29
Nodes (7): output, started_monotonic_ns, launches, flutter, native, output, started_monotonic_ns

### Community 176 - "Synchronized Bilingual Simulator Video Design"
Cohesion: 0.29
Nodes (6): Evidence boundary, Intent, Recording and composition, Shared timeline, Synchronization, Synchronized Bilingual Simulator Video Design

### Community 177 - "synchronized_demo_test.dart"
Cohesion: 0.33
Nodes (5): dart:convert, Directionality, fixture, main, package:ios_sheet_candidate/synchronized_demo.dart

### Community 178 - "timeline_summary"
Cohesion: 0.40
Nodes (5): timeline_summary, duration_ms, languages, scene_count, scene_ids

### Community 179 - "Phase 2 timing diagnostic"
Cohesion: 0.40
Nodes (4): Corrected native boundary results, Corrections and boundary audit, Evidence and unresolved decisions, Phase 2 timing diagnostic

### Community 180 - "dart:async"
Cohesion: 0.50
Nodes (3): dart:async, ProgrammaticReplay, run

### Community 181 - "replay_timing_test.dart"
Cohesion: 0.50
Nodes (3): main, package:fake_async/fake_async.dart, package:ios_sheet_candidate/replay_timing.dart

### Community 182 - "Runtime parity batch — phase 2"
Cohesion: 0.50
Nodes (3): Actual runtime results, Runtime parity batch — phase 2, Verification / next decision

### Community 185 - "_ExampleCardState"
Cohesion: 0.67
Nodes (3): ExampleCard, _ExampleCardState, SingleTickerProviderStateMixin

## Knowledge Gaps
- **1411 isolated node(s):** `schema_version`, `proof_scope`, `split`, `attempt`, `udid` (+1406 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1667 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **36 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Harness` connect `Harness` to `SynchronizedNativeDemoController`, `canonicalDetentID`, `.record`, `ProbeWindow`, `.scene`, `App.swift`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `@immutable`, `observed_profiles.dart`, `package:flutter_test/flutter_test.dart`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `package:flutter/cupertino.dart`, `sheet_logo.dart`, `_`, `playground_page.dart`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `Harness` (e.g. with `.activate()` and `.setOffset()`) actually correct?**
  _`Harness` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `schema_version`, `proof_scope`, `split` to the rest of the system?**
  _1411 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `runtime_batch.py` be split into smaller, more focused modules?**
  _Cohesion score 0.08396396396396397 - nodes in this community are weakly interconnected._
- **Should `ComparisonTests` be split into smaller, more focused modules?**
  _Cohesion score 0.08566895822316235 - nodes in this community are weakly interconnected._