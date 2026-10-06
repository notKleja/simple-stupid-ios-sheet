# Full Native Sheet Parity Continuation Design

## Intent

Finish the behavior set that the first integration documented but did not
implement or validate. The delivered Flutter route must not merely look close
at two resting detents. It must reproduce the observable UIKit sheet contract
for geometry, gesture transfer, target selection, interruption, modality,
scrolling, keyboard coupling, content invalidation, stacking, adaptivity,
accessibility, and frame pacing on the qualified iOS 26 and iOS 27 targets.

The synchronized bilingual video remains demonstration evidence. It cannot
promote any numerical or interaction claim.

## Binding evidence rules

1. Public UIKit computations and repeated native runtime observations outrank
   copied constants, Flutter defaults, visual judgment, and video alignment.
2. A native and Flutter pair is comparable only when OS build, device,
   orientation, scale, safe areas, keyboard, accessibility settings,
   configuration, scenario revision, and gesture recipe all match.
3. Deterministic native-derived behavior requires ten independent trials per
   OS and subcondition. Failed or incomplete attempts remain preserved.
4. Requested input timing is not delivered input timing. Recorded touch
   coordinates and timestamps are required for gesture claims.
5. Alpha is not hit testing, layer radius is not necessarily the visible
   contour, movement correlation is not private scroll ownership, and a build
   or launch is not runtime parity.
6. Unknown, unavailable, and not-applicable observations are distinct states.
   None may be converted to zero or omitted to obtain a pass.
7. The opaque implementation remains independent of Liquid Glass.

## Correct native radius and contour model

The current `cornerRadius: 24` profile value is an explicit fallback and must
not remain the qualified iOS value.

On iOS 26 and later, the native harness reads each corner independently with
`UIView.effectiveRadius(corner:)`. This is UIKit's public computation from the
view's active `cornerConfiguration`; passing multiple corners is forbidden
because UIKit then returns only the maximum. `preferredCornerRadius` remains
automatic and is recorded only as configuration, not as resolved geometry.

The harness identifies the visible clipping surface by stable public
relationships: ancestry relative to `presentationController.presentedView`,
window-space bounds, clipping state, masks, and calibrated pixels. Private
class names may be retained for diagnostics but cannot be selectors in the
acceptance algorithm.

For each candidate clipping ancestor the recorder emits:

- top-left, top-right, bottom-left, and bottom-right effective radii;
- model and presentation bounds, transforms, `cornerRadius`, `cornerCurve`,
  `maskedCorners`, and clipping flags;
- every exposed `CAShapeLayer` mask path as normalized path commands, fill
  rule, and transforms;
- the intersection of ancestor clips;
- a synchronized, opaque, high-contrast raster crop and its physical scale.

If UIKit exposes an opaque continuous renderer instead of a public path, the
accepted contour is the calibrated compositor boundary, not a reconstructed
circular arc. A scalar radius is accepted only when the measured contour
supports that representation. Flutter uses the four UIKit-resolved radii and
a contour implementation that passes symmetric boundary distance, maximum
normal error, topology, and corner-disappearance checks. The target boundary
error is at most 0.5 logical point after a noise study supports that gate.

The shipping package provides an iOS corner-resolution bridge. It asks UIKit
to evaluate `UICornerConfiguration`/`UICornerRadius.containerConcentric` for
the active window and a batch of sheet frames, caches results by environment
and physical-pixel-quantized frame, and returns four radii plus provenance.
No fixed value is silently substituted when the bridge or qualified scope is
unavailable.

## Versioned measurement contracts

Trace schema v2 adds a measurement-condition block separate from the exact
semantic configuration. It carries recipe parameters, input source,
accessibility settings, and applicability. Historical v1 artifacts remain
byte-for-byte immutable.

Scenario IDs are versioned and explicitly mapped between matrix, native, and
Flutter registries. A filename or human-readable similarity never establishes
equivalence.

Every observable declares one of `required`, `not_applicable`, or
`unavailable`. `not_applicable` requires a phase-specific rule; `unavailable`
requires a reason and keeps the check unresolved.

The expanded frame contract includes four-corner radii, contour reference,
barrier effective alpha and hit eligibility, presenter matrix/clip, per-sheet
stack namespace, delivered input, scroll motion, keyboard phase, content
size, size classes, accessibility settings, display timestamps, frame timing,
and input-to-first-visible latency.

## Flutter architecture

The generic `stupid_simple_sheet` engine keeps its public behavior. Native
parity lives in `simple_stupid_ios_sheet` and consumes narrowly-scoped
protected hooks in the generic engine.

One immutable point-space `IosSheetState` is the source for layout, painting,
clipping, hit testing, accessibility, and trace capture. Recording may not
mutate selection or synchronize state as a side effect.

The state pipeline is:

`semantic configuration + observed environment -> resolved detents -> gesture
transfer / target selection / trajectory -> geometry + contour -> barrier /
presenter / stack mapping -> paint + hit testing + observation`.

Separate profile functions own:

- asymmetric overdrag above and below the allowed range;
- release-velocity conversion and any cap;
- exact snap target selection, hysteresis, and detent skipping;
- velocity-preserving interruption and retargeting;
- barrier alpha, hit eligibility, and accessibility eligibility;
- presenter translation, scale, clipping, and overlay;
- per-layer stack mapping;
- keyboard, content-size, orientation, placement, and accessibility
  adaptation.

Fallback functions remain named and instrumented as fallbacks. They never set
the capability status to measured.

## Interaction and modality

The largest undimmed detent controls a real hit-test boundary. Outside the
rendered sheet, the route must allow underlying taps, scrolls, controls, and
focus exactly where the matched native probe allows them. Barrier paint,
pointer eligibility, and semantics are independent outputs so transition
timing can differ when UIKit does.

Scroll arbitration is explicit state with sheet, scroll, or handoff phases.
It consumes delivered delta, content extent, bounce state, direction, and
velocity; it preserves any measured residual movement or momentum. Nested
scrolling, paging, controls, content, and grabber origins are separate cases.
Private UIKit ownership remains unavailable; acceptance observes movement and
delivered outcomes.

## Motion and interruption

All animation requests start from the current point-space position and
velocity. Presentation, detent selection, overdrag return, dismissal,
environment rebase, keyboard rebase, and content invalidation are explicit
phases. Retargeting cannot jump position. Velocity continuity and target
selection are judged against native trajectories; opening interruption remains
unsupported until native evidence is accepted, rather than being guessed.

## Keyboard, content, stacking, and adaptivity

Keyboard observation is separate from keyboard avoidance policy. The package
records actual inset, frame, duration, curve, focus, and interactive dismissal
phase, then applies the native-derived mapping without double-counting safe
areas.

Content detents receive measured content height and expose atomic invalidation
that preserves semantic selection. Dynamic Type, keyboard, and live content
changes use the same invalidation path.

Every stacked route receives a stable layer ID. Geometry, contour, barrier,
presenter transform, focus, hit eligibility, and live/snapshot status are
observable per layer for two- and three-sheet stacks.

Environment resolution includes orientation, horizontal and vertical size
class, page/form style, preferred content size, compact-height edge
attachment, preferred width, source anchor, and supported placement. Profiles
reject unqualified environments rather than extrapolating.

## Accessibility and performance

Reduce Motion selects behavior observed with the setting genuinely enabled;
it is not a launch argument. Dynamic Type uses the actual content category.
Barrier dismissal has a localized semantic label and supports the measured
accessibility escape path while respecting dismissal locks and restoring
focus.

Flutter records `FrameTiming` build/raster/total durations, display frame
timestamps, delivered-input timestamps, missed-frame gaps, and latency to the
first frame that visibly responds. Simulator evidence cannot establish
physical input-to-photon latency and is labeled accordingly.

## Required scenarios

The versioned matrix explicitly covers:

- overdrag above maximum and below minimum with lock/unlock variants;
- position/velocity snap grids and near-threshold holdouts;
- opening, settling, dismissal, and keyboard interruption/retargeting;
- native nonmodal tap, scroll, control, and focus thresholds;
- expand-first, content-first, boundary crossing, second-gesture handoff,
  nested scroll, pager, diagonal, control, content, and grabber origins;
- barrier and presenter transitions in both directions;
- automatic radius and full contour at every detent, during motion, in edge
  attachment, and in stacks;
- keyboard focus, blur, interactive dismissal, and hardware-keyboard cases;
- dynamic content and Dynamic Type invalidation during idle, drag, animation,
  and keyboard motion;
- two- and three-sheet presentation, cancel, and unwind;
- portrait, landscape, compact height, phone, tablet, page, form, preferred
  width, source anchor, and every supported placement;
- Reduce Motion, Dynamic Type, accessibility escape, focus restoration, RTL,
  and localized semantics;
- frame pacing, stalls, dropped frames, input latency, and live-versus-snapshot
  behavior.

## Acceptance and delivery

Resting geometry must be within 0.5 pt and final Y within 0.25 pt. Dynamic Y
must have RMS at most 1 pt and maximum error at most 2 pt. Scale error is at
most 0.001, alpha error at most 0.01, and event/landmark timing at most one
native frame. Discrete outcomes are exact. Observation gaps longer than two
native frames fail coverage.

Every capability publishes its qualified scope and one of `pass`, `fail`, or
`unresolved`. The final report lists unresolved platform limitations without
presenting scaffolding, fixtures, builds, or videos as behavioral completion.

