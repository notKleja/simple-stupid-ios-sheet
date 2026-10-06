# Native iOS Sheet Parity Design

## Intent

Build a Flutter sheet implementation whose observable geometry, detent
resolution, interaction, motion, modality, presenter transformation, scrolling,
keyboard behavior, stacking, adaptivity, accessibility response, and frame
pacing match native Apple sheet presentations on iOS 26 and iOS 27 within the
numeric tolerances in the project mission.

The implementation starts from `stupid_simple_sheet` 1.0.0-dev.4, preserves its
generic route capabilities, and adds an opinionated native-iOS semantic layer.
Its surface is conventional and opaque. Liquid Glass rendering and
`StupidSimpleGlassSheetRoute` are excluded from the shipping path.

## Source of truth

Evidence is accepted in this order:

1. Repeated runtime measurement on native iOS 27.
2. Repeated runtime measurement on native iOS 26.
3. Runtime UIKit and Core Animation values.
4. Apple public API semantics and documentation.
5. Native SwiftUI behavior.
6. Existing Flutter behavior.
7. Upstream package defaults.
8. Visual judgment.

No upstream value becomes a native constant without its own evidence record.
Unmeasured behavior is represented as unresolved or as an explicit fallback,
never as an Apple-derived fact.

## System boundaries

### Native reference harness

`native_reference/` contains one application with UIKit and SwiftUI scenario
registries. Every scenario has a stable `native.*` ID, deterministic content,
and calibration markers. A display-link recorder samples view and presentation
layers, transforms, safe areas, keyboard state, scroll state, gesture state,
velocities, detent identity, and event boundaries into the common JSONL schema.

The harness is measurement software, not a production dependency. Private
runtime inspection may augment evidence but cannot enter the Flutter public
API or shipping runtime.

### Flutter package and candidate harness

`flutter_reference/packages/stupid_simple_sheet/` is a pinned, attributed copy
of upstream. Generic routes remain available. Native parity is exposed through
an opaque iOS route/preset and semantic configuration objects rather than
glass-specific code or raw normalized snap coordinates.

`flutter_reference/apps/parity_harness/` mirrors native scenario IDs and
content. `flutter_reference/apps/playground/` exposes every public option and a
development-only live metrics overlay.

### Measurement contracts

`measurement/schema/` owns versioned schemas for sessions, events, frames,
gesture recipes, scenarios, evidence, and parity reports. Both harnesses emit
the same JSONL envelope:

- `schema_version`, `type`, `run_id`, integer monotonic `t_ns`, and `seq`.
- Session records contain scenario, implementation, evidence kind, OS, device,
  environment, and configuration.
- Event records identify real boundaries such as presentation requested,
  started, and settled; gesture began and ended; detent requested and settled;
  dismissal requested and settled.
- Frame records expose flat dotted metrics and discrete state. Unknown values
  are `null` with an unavailability reason.

Raw native, Flutter, and synthetic traces are never conflated. Synthetic
fixtures validate analyzer mathematics only.

### Analyzer and regression system

`analysis/` validates traces, aligns them at recorded event boundaries,
interpolates only where the metric permits it, computes static and dynamic
errors, estimates measurement noise, fits candidate transfer functions, and
emits machine-readable PASS/FAIL reports plus optional plots.

The regression matrix is machine-readable and covers OS, device, orientation,
detents, interaction, modality, and content. Holdout gesture recipes are kept
separate from tuning recipes and are run only after a candidate profile is
frozen.

### Evidence and profiles

`spec/evidence.json` is the provenance database for every implementation
constant or formula. `spec/ios26.json` and `spec/ios27.json` contain only
measured or documented profile values with confidence and sample metadata.
`spec/DIFF_26_27.md` classifies findings as identical, measurably different,
visually different only, behavioral difference, or unresolved.

`spec/MASTER_STATE.md` is the compact integration ledger: accepted facts,
architecture, unresolved questions, active pull requests, parity score, and the
next three highest-value tasks.

## Flutter semantic model

The public layer represents Apple concepts directly:

- typed system, fixed-height, fractional, content, and custom detents;
- selected and initial detent through a controller;
- largest undimmed detent and corresponding hit-testing semantics;
- draggable, dismissible, and interactive-dismiss-disabled policy;
- expand-first and scroll-first content interaction;
- grabber visibility;
- page, form, edge-attached, preferred-width, and placement policy;
- corner override and opaque background/barrier styling;
- keyboard policy, lifecycle hooks, and debug metrics.

Resolved geometry is expressed in logical points after safe-area, keyboard,
size-class, and placement context are known. Internal normalized progress may
be used as a derived value but cannot be the only representation of native
detents.

## Motion and gesture model

The engine separates five concerns:

1. A detent resolver maps semantic detents and layout context to positions.
2. A gesture transfer function maps finger displacement to sheet displacement,
   including measured asymmetric overdrag.
3. A target selector uses position, velocity, direction, detent adjacency, and
   any measured hysteresis or predicted endpoint behavior.
4. A trajectory model produces velocity-continuous movement and can be
   interrupted or retargeted without positional jumps.
5. A presentation mapper independently derives barrier and presenter state
   from measured mappings rather than assuming linear sheet progress.

Separate iOS profiles provide version-correct formulas. A fallback profile is
allowed only when the active platform cannot be identified, and its evidence
record must say that it is a fallback.

## Modality and scrolling

Nonmodal behavior is implemented with actual hit-test routing, not only zero
barrier opacity. The largest undimmed detent determines both visual dimming and
underlying interaction eligibility. Transitions into and out of modal detents
are observable state changes and participate in traces.

Scroll arbitration is stateful. It records and resolves which participant owns
vertical movement, preserves momentum when native behavior does, and handles
top-edge tolerance, bounce, nested scrolling, horizontal paging, interactive
children, and grabber-originated gestures without a positional discontinuity.

## Validation policy

Each measured scenario is repeated at least ten times where deterministic
motion constants are derived. Geometry, motion, alpha, transform, interaction,
and state-transition tolerances match the mission. When observed noise exceeds
a target, the report quantifies the noise and derives a statistical tolerance;
it does not silently loosen the target.

Build success, simulator launch, vPhone launch, schema validation, and analyzer
fixture success prove different layers. Reports must name the highest layer
actually observed. No run is called native parity without fresh native and
Flutter traces from corresponding scenarios on the same target configuration.

## Failure handling

- Missing runtime or device access records a blocker and leaves values
  unresolved; it never triggers guessed constants.
- Invalid or incomplete traces fail validation before comparison.
- Dropped or non-monotonic frames are reported and excluded only under an
  explicit documented rule.
- Interrupted collection preserves partial raw evidence with a terminal error
  event rather than presenting it as a completed run.
- Profile lookup failure selects the documented fallback and emits a debug
  diagnostic.
- Analyzer alignment failure is a report failure, not a zero-error comparison.

## Delivery sequence

The three parallel capability tracks establish the native recorder, Flutter
engine/API, and measurement/analyzer contracts. The master integrates only
committed, reviewed branch ranges; reconciles their interfaces; runs combined
tests; then advances from baseline scenarios to geometry, physics, modality,
scrolling, keyboard, stacking, adaptivity, accessibility, performance, and the
adversarial holdout run.

