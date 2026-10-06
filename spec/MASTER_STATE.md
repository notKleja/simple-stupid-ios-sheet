# Master state

## Accepted facts

- Native iOS runtime measurement outranks package defaults and visual judgment.
- iOS 26 and iOS 27 require independent profiles when behavior differs.
- The shipping surface is opaque; Liquid Glass is excluded.
- `stupid_simple_sheet` 1.0.0-dev.4 is vendored with its MIT license and 115
  upstream tests preserved.
- Ninety native traces across nine accepted ten-trial profiles pass the cohort
  integrity gate; 50 non-resting geometry gaps remain explicit.
- The matched 402×874 iOS 26/27 page cohorts have identical resting medium and
  large geometry. System medium is `0.56 × maximum` in every accepted cohort.
- A regular-width 320×320 preferred-content form resolves to maximum 330 pt on
  iOS 26 and 1158 pt on iOS 27 in the measured iPad environment.
- The actual v2 native/candidate pair has matching metadata, configuration,
  canonical events, and state transitions, but fails timing and tail coverage.

## Architecture

- A native UIKit/SwiftUI harness and Flutter harness share scenario IDs.
- Both emit a versioned JSONL measurement schema.
- A trace analyzer aligns on recorded event boundaries and produces numerical
  parity results.
- The Flutter implementation is an opinionated native-iOS layer over the
  package's generic route engine, extending the engine only when measured
  behavior cannot be represented.

## Unresolved questions

- No usable iOS 27 vPhone exists in the current inventory.
- Full presentation, detent, dismissal, and interruption trajectories remain
  unresolved because accepted native traces retain explicit gaps/anomalies.
- Gesture physics, overdrag, snap policy, actual nonmodal hit testing, scroll
  handoff, keyboard synchronization, stacking, radius/contour, barrier alpha,
  accessibility, landscape, and performance remain unmeasured.
- Opening interruption is explicitly rejected by the Flutter foundation until
  a measured velocity-continuous implementation is available.

## Active pull requests

- PR #19 measurement infrastructure — merged.
- PR #20 native reference — merged.
- PR #21 Flutter engine — merged.

## Current parity score

- Resting geometry for the sampled 402×874 medium/large configuration: exact
  repeated match in both iOS 26 and iOS 27 candidate cohorts.
- Contract compatibility: exact for the actual iOS 26 v2 pair.
- Dynamic pair verdict: FAIL. Timing errors are 61.89–302.35 ms against a
  16.67 ms frame limit, first-visible error is 127.00 ms, and candidate tail
  coverage is incomplete.
- Full matrix: unresolved; 248 cells and 1,480 mandatory checks are defined.

## Next three highest-value tasks

1. Make candidate command timing and trace-tail semantics match native, then
   collect ten fresh paired trials on both OS versions.
2. Add deterministic vPhone gesture, nonmodal hit-test, and scroll-handoff
   experiments and use them to implement measured interaction behavior.
3. Measure and implement keyboard, stacking, radius/contour, barrier/presenter,
   interruption, accessibility, and performance profiles before holdout replay.
