# Synchronized Bilingual Simulator Video Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and record a simultaneous native-versus-Flutter bilingual iPhone 17 Pro scenario playlist.

**Architecture:** A shared JSON timeline drives native and Flutter demo modes from an absolute epoch. A Python coordinator provisions two identical simulators, builds and installs both apps, launches them against the same start time, records both streams, composes a side-by-side MP4, and emits a hashed manifest.

**Tech Stack:** Swift/UIKit, Dart/Flutter, Python 3, simctl, xcodebuild, FFmpeg.

**Spec:** `docs/superpowers/specs/2026-10-07-synchronized-video-design.md`

## Global Constraints

- Use two fresh iPhone 17 Pro simulators on the same iOS 26.4.1 runtime.
- Native and Flutter consume the same timeline asset and absolute start time.
- Languages are English/LTR and Arabic/RTL.
- Keep the surface opaque; no Liquid Glass or glass-route dependency.
- Preserve raw recordings and do not crop or retime one side to fake parity.
- Label unresolved properties and keep numerical parity claims in the analyzer.

## Review Focus

- Missing or late app launch must fail the run rather than record one idle side.
- A malformed or overlapping timeline must fail validation before build.
- Locale changes must affect both text and directionality.
- Scene/action state must be derived from the absolute clock, not chained sleeps.
- The final manifest must hash the exact timeline, raw videos, and composite.

---

### Task 1: Timeline contract

**Files:**
- Create: `measurement/scenarios/synchronized_bilingual_demo.json`
- Create: `measurement/scripts/validate_demo_timeline.py`
- Test: `measurement/tests/test_demo_timeline.py`

- [ ] Write failing tests for overlapping scenes, missing Arabic scenes, non-monotonic actions, and a valid literal fixture.
- [ ] Run `python3 -m unittest measurement/tests/test_demo_timeline.py -v` and confirm the validator is absent.
- [ ] Implement strict validation and the concrete playlist.
- [ ] Rerun the focused test and the full analyzer suite.

### Task 2: Native demo mode

**Files:**
- Create: `native_reference/NativeSheetHarness/SynchronizedDemo.swift`
- Modify: `native_reference/NativeSheetHarness/App.swift`
- Modify: `native_reference/scripts/build.sh`
- Test: `native_reference/tests/test_demo_contract.py`

- [ ] Write a failing contract test that asserts every shared scene maps to a native configuration and localized copy.
- [ ] Implement timeline parsing, epoch scheduling, bilingual/RTL fixtures, scene overlays, and native sheet actions.
- [ ] Build for iPhone simulator and verify the demo reaches its armed screen.

### Task 3: Flutter demo mode

**Files:**
- Create: `flutter_reference/candidate/lib/synchronized_demo.dart`
- Modify: `flutter_reference/candidate/lib/main.dart`
- Modify: `flutter_reference/candidate/ios/Runner/AppDelegate.swift`
- Modify: `flutter_reference/candidate/pubspec.yaml`
- Test: `flutter_reference/candidate/test/synchronized_demo_test.dart`

- [ ] Write failing widget tests for scene selection, absolute-clock action selection, English LTR, and Arabic RTL.
- [ ] Implement the shared-asset parser and demo widget using the semantic iOS sheet route.
- [ ] Run all Flutter tests, analyzers, and an arm64 simulator build.

### Task 4: Dual simulator coordinator and video

**Files:**
- Create: `measurement/scripts/record_synchronized_demo.py`
- Test: `measurement/tests/test_record_synchronized_demo.py`
- Create at runtime: `artifacts/video/<run-id>/manifest.json`

- [ ] Write failing unit tests for device/runtime selection, command construction, equal-duration composition, and manifest hashes.
- [ ] Implement clean simulator creation, synchronized launch/record, FFmpeg composition, and fail-closed cleanup.
- [ ] Execute one full run and verify both raw streams, composite duration/frame rate, timeline hash, and simulator metadata.
- [ ] Copy the user-facing MP4 and manifest into the projectless task `outputs/` directory.

