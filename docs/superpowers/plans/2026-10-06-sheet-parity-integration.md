# Native iOS Sheet Parity Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the native harness, Flutter engine, and measurement analyzer into one evidence-backed iOS 26/27 parity system and execute the acceptance matrix.

**Architecture:** Three isolated branches own native measurement, Flutter implementation, and parity analysis. The main branch integrates stable contracts first, then each reviewed capability branch, and accepts native-profile values only after fresh paired traces pass schema and provenance gates.

**Tech Stack:** Swift/UIKit/SwiftUI/XCTest, Dart/Flutter/flutter_test, Python/pytest/JSON Schema, GitHub CLI, xcodebuild/simctl, vPhone CLI.

**Spec:** `docs/superpowers/specs/2026-10-06-native-ios-sheet-parity-design.md`

## Global Constraints

- Native runtime evidence outranks package defaults and visual judgment.
- iOS 26 and iOS 27 profiles remain separate wherever measurements differ.
- No Liquid Glass dependency or final use of `StupidSimpleGlassSheetRoute`.
- Synthetic fixtures validate analyzer mathematics only, never native parity.
- Every shipping constant has a native measurement, documented Apple semantic, derived formula, or explicit fallback evidence entry.
- Exactness is determined by the mission tolerances and exact discrete outcomes.
- CLI/API workflows only; no Computer Use.

## Review Focus

- A successful build without runtime traces must remain classified as build-only evidence.
- A vPhone or simulator launch without a complete trace must not update platform profiles.
- Unknown or unavailable metrics on one side must be unresolved, not treated as zero error.
- Native and Flutter traces with different device, orientation, OS build, keyboard, or configuration metadata must not compare as a parity pair.
- Holdout recipes must remain excluded from profile tuning until the profile is frozen.

---

### Task 1: Integrate the measurement contract

**Files:**
- Merge from: `test/parity-harness`
- Review: `measurement/CONTRACT.md`
- Review: `measurement/schema/trace.schema.json`
- Review: `measurement/schema/evidence.schema.json`
- Review: `measurement/schema/gesture.schema.json`
- Modify: `spec/evidence.json`

**Interfaces:**
- Produces: the canonical JSONL v1 envelope and provenance contract consumed by both harnesses.

- [ ] Record the branch base and generate a full review package from the base through the contract commit.
- [ ] Review required session, event, frame, timing, state, null-reason, evidence-kind, and failure-closed semantics against the design spec.
- [ ] Run the schema tests documented by the branch and confirm invalid fixtures fail.
- [ ] Integrate the reviewed commit and update the seed evidence file to the accepted schema without inventing entries.
- [ ] Run schema validation over every checked-in JSON artifact.
- [ ] Commit with `feat(measurement): integrate trace contract`.

### Task 2: Integrate the analyzer and regression matrix

**Files:**
- Merge from: `test/parity-harness`
- Review: `analysis/`
- Review: `measurement/matrix/`
- Review: `measurement/gestures/`

**Interfaces:**
- Consumes: canonical traces and mission tolerances.
- Produces: event-aligned static/dynamic metrics, fitting/noise results, PASS/FAIL reports, and tuning/holdout run manifests.

- [ ] Review the full branch diff for event-boundary alignment, incompatible-metadata rejection, null/missing-metric rejection, evidence-kind separation, and tolerance handling.
- [ ] Run the complete analyzer test suite from a clean environment.
- [ ] Verify analytic synthetic fixtures cover absolute, RMS, maximum, time-offset, velocity, exact state, and noise-derived tolerance calculations.
- [ ] Verify the matrix contains every required mission dimension and that holdout recipes cannot enter tuning runs.
- [ ] Integrate the reviewed range and run schema plus analyzer suites together.
- [ ] Commit with `feat(analysis): integrate parity tooling`.

### Task 3: Integrate the native reference harness

**Files:**
- Merge from: `research/native-reference`
- Review: `native_reference/`
- Review: `artifacts/native/`
- Modify: `spec/MASTER_STATE.md`

**Interfaces:**
- Consumes: scenario, gesture, trace, and evidence contracts.
- Produces: deterministic native scenarios and validated runtime traces.

- [ ] Review the branch diff for public API configuration, opaque calibration content, stable scenario IDs, display-link sampling, real event boundaries, partial-run failure marking, and CLI-only collection.
- [ ] Run native unit tests and clean simulator builds on the available iOS 26.4.1 and iOS 27.0 runtimes.
- [ ] Collect one complete baseline trace per runtime and validate both against the canonical schema.
- [ ] Confirm the connected vPhone target is reported separately from simulator evidence and that launch-only evidence is not promoted to behavioral measurement.
- [ ] Integrate the reviewed range and update master state with only observed facts.
- [ ] Commit with `feat(native): integrate reference harness`.

### Task 4: Integrate the Flutter engine and public API

**Files:**
- Merge from: `feat/ios-sheet-engine`
- Review: `flutter_reference/`
- Review: `analysis/upstream_architecture.md`
- Modify: `spec/MASTER_STATE.md`

**Interfaces:**
- Consumes: native profile and trace contracts.
- Produces: attributed upstream fork, semantic opaque iOS API, separate profile seams, parity harness, and playground.

- [ ] Verify the vendored archive is 1.0.0-dev.4 and matches SHA-256 `13ebc967c9a9fd2f60c675f9dafe4e0cfedb1d1dfd50256d408903a01bfb87ad`.
- [ ] Review the branch for preserved MIT attribution, passing upstream behavior, point-resolved detents, independent iOS 26/27 seams, semantic modality/dismissal/content-interaction APIs, and absence of glass dependencies in the final route.
- [ ] Run the full upstream and new Flutter unit/widget suites.
- [ ] Build the parity harness for the available iOS targets and validate one Flutter baseline trace per runtime.
- [ ] Integrate the reviewed range and update master state without presenting fallback values as native measurements.
- [ ] Commit with `feat(flutter): integrate native sheet engine`.

### Task 5: Reconcile contracts and complete measured profiles

**Files:**
- Modify: `native_reference/`
- Modify: `flutter_reference/`
- Modify: `measurement/`
- Modify: `analysis/`
- Modify: `spec/evidence.json`
- Modify: `spec/ios26.json`
- Modify: `spec/ios27.json`
- Modify: `spec/DIFF_26_27.md`

**Interfaces:**
- Consumes: reviewed integrated components and repeated native trials.
- Produces: compatible recorders, accepted formulas/constants, and version-correct Flutter profiles.

- [ ] Run repository-wide contract tests and resolve every schema, scenario-ID, metric-name, unit, timing, and availability mismatch through reviewed fixes.
- [ ] Collect at least ten native trials for each deterministic baseline transition and the controlled geometry, overdrag, release, barrier, presenter, scrolling, keyboard, stacking, and interruption experiments available on both OS versions.
- [ ] Estimate noise, fit competing hypotheses, and accept a model only when residuals and repeated trials distinguish it from alternatives.
- [ ] Add evidence entries with source artifact, OS build, device, scenario, samples, dispersion, units, confidence, and formula/value.
- [ ] Implement accepted profile differences and run focused Flutter tests before collecting fresh candidate traces.
- [ ] Commit with `feat(parity): apply measured iOS profiles`.

### Task 6: Execute parity and adversarial acceptance

**Files:**
- Create: `docs/PARITY_REPORT.md`
- Create: `artifacts/acceptance/manifest.json`
- Modify: `spec/MASTER_STATE.md`

**Interfaces:**
- Consumes: frozen profiles, paired scenarios, tuning matrix, and hidden holdout recipes.
- Produces: final numerical acceptance report and explicit unresolved discrepancies.

- [ ] Perform clean native and Flutter builds for each available iOS 26 and iOS 27 target.
- [ ] Collect fresh paired traces using identical scenario metadata and automated gesture recipes.
- [ ] Generate reports for resting geometry, detents, inset/radius evolution, presentation/dismissal trajectories, snap outcomes, overdrag, presenter transform, barrier, hit testing, scroll handoff, keyboard, stacking, adaptivity, accessibility, and performance.
- [ ] Freeze the profiles and run the adversarial holdout suite without retuning.
- [ ] Search the dependency and source trees for glass-route or Liquid Glass dependencies in the final implementation and require an empty shipping-path result.
- [ ] Publish exact, within-tolerance, known platform-limited, and unresolved results with direct artifact/evidence references.
- [ ] Commit with `docs: publish final parity report`.

