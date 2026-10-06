# Full Native Sheet Parity Continuation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the remaining fallback sheet behavior with separately qualified iOS 26/27 measurements, implementations, and paired acceptance evidence.

**Architecture:** Version the measurement contract first, then extend the native harness, accept native models, implement one observable point-space Flutter state pipeline, and collect fresh paired cohorts before holdouts. Existing raw artifacts remain immutable and visual demonstrations stay evidence-limited.

**Tech Stack:** Swift/UIKit/XCTest, Dart/Flutter/flutter_test, Python 3/unittest/JSON Schema, simctl, xcodebuild, FFmpeg only for labeled visual evidence.

**Spec:** `docs/superpowers/specs/2026-10-07-full-native-sheet-parity-continuation.md`

## Global Constraints

- Native runtime evidence outranks package defaults and visual judgment.
- iOS 26 and iOS 27 profiles remain separate wherever measurements differ.
- No Liquid Glass dependency or final use of `StupidSimpleGlassSheetRoute`.
- Historical raw evidence remains byte-for-byte immutable.
- Every shipping value or formula has public UIKit semantics, repeated native evidence, or an explicit fallback status.
- Exactness is judged by rendered/observed outcomes, not equal configured constants.
- CLI/API workflows only; no Computer Use.

## Review Focus

- A clipping ancestor or shadow path must not be mistaken for the visible contour.
- Requested XCTest motion must not be treated as delivered touch position or velocity.
- `not_applicable`, `unavailable`, and numeric zero must remain distinguishable.
- Barrier opacity must not substitute for underlying hit-test evidence.
- Simulator frame pacing must not be reported as physical input-to-photon latency.

---

### Task 1: Integrate completed phase-two branches

**Files:**
- Merge: `research/native-interactions@b90c78f`
- Merge: `fix/runtime-timing-parity@3802c57`
- Merge: `test/runtime-parity-batch@ecf6480`
- Preserve: `feat/synchronized-demo-video@5a8d088`
- Modify: `flutter_reference/candidate/lib/main.dart`
- Modify: `flutter_reference/candidate/pubspec.yaml`
- Modify: `native_reference/NativeSheetHarness/App.swift`

**Interfaces:**
- Consumes: phase-one canonical configuration and trace v1.
- Produces: one branch containing discrete native interactions, strict timing, frozen runtime batching, and visual demo modes without conflating their evidence.

- [ ] Record the branch base and merge native interactions first, timing second, runtime batching third.
- [ ] Resolve `App.swift` by keeping both interaction replay and `SHEET_DEMO` routing; each mode must be mutually exclusive and retain its original acknowledgement or trace output.
- [ ] Resolve Flutter `main.dart` and `pubspec.yaml` by preserving canonical autorun, strict replay timing, and synchronized-demo bootstrap as separate modes.
- [ ] Run 26 native interaction tests, 54 analyzer tests, 150 Flutter tests, candidate/package analyzers, and both arm64 simulator builds.
- [ ] Validate old manifest and artifact hashes and regenerate graph outputs once on the combined tree.
- [ ] Commit with `chore: integrate phase-two evidence`.

### Task 2: Version scenario, condition, and applicability contracts

**Files:**
- Modify: `measurement/schema/trace.schema.json`
- Modify: `measurement/schema/scenario.schema.json`
- Create: `measurement/schema/trace-v2.schema.json`
- Create: `measurement/runtime/scenario-map-v2.json`
- Modify: `measurement/profiles/full.json`
- Modify: `spec/test_matrix.json`
- Modify: `analysis/runtime_batch.py`
- Test: `measurement/tests/`
- Test: `analysis/tests/test_runtime_batch.py`

**Interfaces:**
- Produces: trace v2 `conditions`, versioned scenario mapping, and per-phase applicability consumed by both recorders and batch analysis.

- [ ] Write failing tests proving trace v1 bytes still validate, v2 accepts `conditions`, the semantic configuration remains exact, unknown conditions fail, and scenario aliases require an explicit map entry.
- [ ] Run the focused tests and confirm failures are caused by absent v2/schema-map support.
- [ ] Add `conditions` with exact keys `recipe_id`, `recipe_revision`, `parameters`, `input_source`, `accessibility`, and `applicability`; applicability values are only `required`, `not_applicable`, or `unavailable`.
- [ ] Add phase-specific rules for target detent, scroll observations, hit testing, keyboard, stack layers, contour, and performance; unresolved required values fail closed.
- [ ] Expand explicit matrix cases for the behaviors in the spec while keeping tuning and holdout assignments disjoint.
- [ ] Run all schema/analyzer tests and commit with `feat(measurement): version behavior conditions`.

### Task 3: Measure UIKit radii, contour, barrier, and presenter

**Files:**
- Create: `native_reference/NativeSheetHarness/GeometryProbe.swift`
- Modify: `native_reference/NativeSheetHarness/App.swift`
- Modify: `native_reference/NativeSheetHarness/Trace.swift`
- Create: `native_reference/scripts/extract_contour.py`
- Create: `native_reference/scripts/validate_geometry_probe.py`
- Test: `native_reference/tests/GeometryProbeContractTests.swift`
- Test: `native_reference/tests/test_geometry_probe.py`
- Create: `artifacts/native/geometry-v2/`

**Interfaces:**
- Produces: per-corner UIKit effective radii, exposed mask paths, calibrated raster contours, classified dimming observations, and presenter transforms with source-tagged cohorts.

- [ ] Write Swift contract tests for independent corner ordering, stable ancestry-relative IDs, shape-path serialization, and public-only candidate selection; write Python tests using hand-derived square/circle/asymmetric contour fixtures and a shadow boundary that must be rejected.
- [ ] Verify the tests fail because the probe and contour comparator do not exist.
- [ ] Implement `GeometryProbe` to call `effectiveRadius(corner:)` separately for four corners, serialize public mask paths and ancestor clip intersections, and never select by private class name.
- [ ] Add high-contrast raster synchronization and classify the dimming view by containment, interaction, and calibrated alpha rather than class name.
- [ ] Record presenter model/presentation transforms, anchor, clip, opacity, and stack-relative identity.
- [ ] Collect ten complete trials for iOS 26.4.1 and iOS 27.0 for fixed/medium/large transitions, both directions, page/form, and two-sheet front/rear states; retain every failed attempt.
- [ ] Estimate contour/pixel noise, accept only supported representations, update `spec/evidence.json`, and commit with `feat(native): measure sheet contour and presentation`.

### Task 4: Measure gestures, snap decisions, interruption, and scrolling

**Files:**
- Create: `native_reference/NativeSheetHarness/DynamicsProbe.swift`
- Modify: `native_reference/NativeSheetHarness/InteractionProbe.swift`
- Modify: `native_reference/NativeSheetHarness/NativeScenario.swift`
- Modify: `native_reference/XCTests/NativeInteractionUITests.swift`
- Create: `native_reference/scripts/collect_dynamics.py`
- Test: `native_reference/tests/test_dynamics.py`
- Create: `artifacts/native/dynamics-v2/`

**Interfaces:**
- Produces: delivered-input transfer samples, overdrag functions, snap grids, interruption trajectories, and observable scroll/sheet handoff outcomes.

- [ ] Write failing tests for a literal recipe grid spanning both boundaries, lock states, release velocities, detent spacing, interruption phases, scroll offsets, gesture origins, nested/pager/diagonal cases, and a second gesture after reaching the top.
- [ ] Verify the collector rejects requested-input-only runs, missing delivery, gaps over two frames, and cohorts with fewer than ten independent trials.
- [ ] Record delivered touch position/time/velocity, public recognizer state, sheet position, scroll offset, and final detent without claiming private ownership.
- [ ] Implement deterministic shared-clock retarget requests at 100 ms and 200 ms during opening, detent motion, and dismissal.
- [ ] Collect iOS 26/27 cohorts, fit competing transfer/target/trajectory hypotheses, freeze training models, then run untouched threshold/one-point/reversal holdouts.
- [ ] Update versioned profile evidence and commit with `feat(native): measure sheet interaction dynamics`.

### Task 5: Measure keyboard, content, stacking, adaptivity, and accessibility

**Files:**
- Create: `native_reference/NativeSheetHarness/AdaptationProbe.swift`
- Modify: `native_reference/NativeSheetHarness/NativeScenario.swift`
- Modify: `native_reference/XCTests/NativeInteractionUITests.swift`
- Create: `native_reference/scripts/collect_adaptation.py`
- Test: `native_reference/tests/test_adaptation.py`
- Create: `artifacts/native/adaptation-v2/`

**Interfaces:**
- Produces: keyboard phase mapping, detent invalidation behavior, per-layer stacks, environment resolution, accessibility outcomes, and native pacing baselines.

- [ ] Write failing recipe-validation tests for focus/blur/interactive dismissal, hardware keyboard, dynamic content invalidation, Dynamic Type changes, two/three stacks, top-cancel/unwind, portrait/landscape rotation, compact attachment, preferred width, page/form/placement, Reduce Motion, accessibility escape, focus restoration, and RTL.
- [ ] Record actual keyboard frame/duration/curve, focus, content size, selected detent, every stack layer, size classes, orientation, verified settings, display timestamps, and callback landmarks.
- [ ] Use public `invalidateDetents()`, nested presentations, `XCUIDevice.orientation`, verified `simctl ui content_size`, and the public accessibility escape action; never use launch flags as setting evidence.
- [ ] Collect ten complete trials per supported OS/subcondition, preserve unsupported combinations as unresolved, and publish noise/latency baselines.
- [ ] Commit with `feat(native): measure sheet adaptation`.

### Task 6: Implement the point-space Flutter state and geometry pipeline

**Files:**
- Create: `flutter_reference/packages/ios_sheet/lib/src/environment.dart`
- Create: `flutter_reference/packages/ios_sheet/lib/src/state.dart`
- Create: `flutter_reference/packages/ios_sheet/lib/src/motion.dart`
- Create: `flutter_reference/packages/ios_sheet/lib/src/geometry.dart`
- Create: `flutter_reference/packages/ios_sheet/lib/src/corner_bridge.dart`
- Create: `flutter_reference/packages/ios_sheet/ios/Classes/IosSheetCornerPlugin.swift`
- Create: `flutter_reference/packages/ios_sheet/ios/ios_sheet.podspec`
- Modify: `flutter_reference/packages/ios_sheet/pubspec.yaml`
- Modify: `flutter_reference/packages/ios_sheet/lib/src/profile.dart`
- Modify: `flutter_reference/packages/ios_sheet/lib/src/route.dart`
- Modify: `flutter_reference/packages/stupid_simple_sheet/lib/stupid_simple_sheet.dart`
- Test: `flutter_reference/packages/ios_sheet/test/state_motion_test.dart`
- Test: `flutter_reference/packages/ios_sheet/test/geometry_test.dart`

**Interfaces:**
- Consumes: accepted native geometry/dynamics profile functions.
- Produces: immutable `IosSheetState`, phase-specific requests, point-space velocity continuity, four-corner contour geometry, and pure observation snapshots.

- [ ] Write failing tests using literal accepted fixtures for environment scope, four-corner radii, contour boundary samples, position/velocity continuity, snap targets, asymmetric overdrag, dismissal, retargeting, and environment rebase.
- [ ] Verify each test fails for the absent state/geometry/motion API.
- [ ] Add one protected generic-engine simulation factory that receives current position and velocity while preserving all upstream defaults.
- [ ] Implement the immutable state reducer and profile functions; opening interruption remains an explicit unsupported error unless Task4 evidence accepts it.
- [ ] Implement the iOS corner bridge/batch cache and use one geometry object for paint, clip, hit testing, and trace output; failure returns an explicit unsupported capability, never24.
- [ ] Make `captureFrame()` observational with no selection mutation.
- [ ] Run package/API/candidate suites, contour goldens, analyzers, and arm64 simulator builds; commit with `feat(flutter): add native state and contour pipeline`.

### Task 7: Implement interaction, presentation, stacking, and adaptation

**Files:**
- Create: `flutter_reference/packages/ios_sheet/lib/src/interaction.dart`
- Create: `flutter_reference/packages/ios_sheet/lib/src/presentation.dart`
- Create: `flutter_reference/packages/ios_sheet/lib/src/stack.dart`
- Create: `flutter_reference/packages/ios_sheet/lib/src/adaptation.dart`
- Modify: `flutter_reference/packages/ios_sheet/lib/src/route.dart`
- Modify: `flutter_reference/packages/ios_sheet/lib/src/detents.dart`
- Modify: `flutter_reference/packages/ios_sheet/lib/src/trace.dart`
- Test: `flutter_reference/packages/ios_sheet/test/interaction_test.dart`
- Test: `flutter_reference/packages/ios_sheet/test/presentation_stack_test.dart`
- Test: `flutter_reference/packages/ios_sheet/test/adaptation_test.dart`

**Interfaces:**
- Consumes: accepted native mappings and `IosSheetState`.
- Produces: real nonmodal routing, observable scroll arbitration, independent barrier/presenter maps, per-layer stacks, keyboard/content/environment adaptation, accessibility policy, and frame timing observations.

- [ ] Write failing real-widget tests for activate/block/activate background taps, underlying scroll/focus, explicit handoff transitions, nested/pager/control origins, barrier reversal, presenter mapping, two/three-stack unwind, keyboard phases, content invalidation, compact placement, Reduce Motion, Dynamic Type, localized dismissal, escape, and focus restoration.
- [ ] Verify failures are observable behavior failures, not source-text checks or mock existence.
- [ ] Implement independent alpha/hit/semantics outputs and a sheet-bounds hit-test router.
- [ ] Implement interaction state and residual-delta transfer from Task4 without inventing private ownership.
- [ ] Implement presenter/stack maps through delegated and secondary transitions driven by the same state snapshot.
- [ ] Populate actual keyboard/content/environment/accessibility observations, atomic detent invalidation, and `FrameTiming`/input-latency tracing.
- [ ] Run all Flutter tests/analyzers/builds and commit with `feat(flutter): complete native behavior pipeline`.

### Task 8: Collect paired cohorts and execute final acceptance

**Files:**
- Modify: `flutter_reference/candidate/`
- Modify: `analysis/runtime_batch.py`
- Modify: `spec/ios26.json`
- Modify: `spec/ios27.json`
- Modify: `spec/DIFF_26_27.md`
- Modify: `spec/MASTER_STATE.md`
- Modify: `docs/PARITY_REPORT.md`
- Create: `artifacts/runtime/full-v2/`
- Create: `artifacts/acceptance/full-v2-report.json`

**Interfaces:**
- Consumes: frozen profiles, versioned recipes, native cohorts, and matching Flutter scenarios.
- Produces: immutable paired reports, holdout results, and explicit pass/fail/unresolved status for every requested behavior.

- [ ] Mirror every accepted native recipe in the candidate with identical conditions and delivered-observation fields.
- [ ] Build clean native and Flutter apps for both available simulator runtimes and collect ten matched Flutter trials per accepted native subcondition.
- [ ] Validate hashes, provenance, metadata, coverage, applicability, and scenario mapping before comparison.
- [ ] Run unchanged geometry, contour, motion, timing, alpha, transform, hit-test, scroll, keyboard, stack, adaptation, accessibility, and performance gates.
- [ ] Freeze profile hashes, run the untouched holdout suite without retuning, and fail any threshold/outcome mismatch.
- [ ] Update the master state and parity report with direct artifact references and honest unresolved platform limitations.
- [ ] Regenerate the synchronized representative video from the same recipe revision without using it as numerical proof.
- [ ] Run repository-wide tests, analyzers, builds, integrity validation, and a whole-branch review; commit with `docs: publish full sheet parity evidence`.
