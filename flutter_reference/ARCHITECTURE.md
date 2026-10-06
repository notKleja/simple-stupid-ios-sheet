# Flutter engine and opaque API

`stupid_simple_sheet` 1.0.0-dev.4 is vendored unchanged except for narrow,
backward-compatible physics/scroll seams and standalone legacy-example
workspace configuration. Its full upstream test suite is retained. The
new `simple_stupid_ios_sheet` package exports the opaque API, not the legacy
glass route. The candidate never constructs a glass route; its dependency
closure has no Liquid Glass rendering package.

## Architecture map

| Concern | Upstream foundation | Opaque layer |
| --- | --- | --- |
| Route | `PopupRoute` + transition/controller mixins | `StupidSimpleIosSheetRoute` |
| Controller | `animateToRelative`, `overrideSnappingConfig` | semantic `IosSheetController.selectDetent` |
| Detents | normalized snap positions, implicit closed0 | point/fraction/custom IDs; validation, sorting, independent visible-height conversion |
| Snap target | `AbsoluteSnapPhysics` / `RelativeSnapPhysics` | profile-injected physics; defaults remain unmeasured |
| Motion | `motor` spring/curve simulations | replaceable `Motion`; no native spring constants asserted |
| Scroll | `ScrollDragDetector`, start/continuous handoff | content-resizes / content-scrolls policy |
| Overdrag | delta resistance and scaled release velocity | optional arbitrary point-based transfer functions |
| Rendering | slide/shrink; custom route extension | opaque clipped shape, independent insets/uniform scale |
| Modality | modal barrier | detent-ID threshold controls alpha AND real pointer passthrough |
| Presenter | Cupertino delegated secondary transition, snapshots | native transformation not implemented yet; live generic background |
| Snapshotting | never/animating/settled/openAndForward/always | retained in generic routes; opaque default is live |
| Recorder | none | post-layout transformed corners, JSONL v1, actual native metadata in candidate |

`Motion` is a simulation factory. `SpringMotion` passes start/end/velocity to
Flutter `SpringSimulation`; `CupertinoMotion` derives a spring description from
duration/bounce. `CurvedMotion` ignores incoming velocity and uses fixed-duration
`CurveSimulation`. Thus a fixed curve is unsuitable when measured continuity
requires initial velocity preservation. The existing imperative engine path
preserves controller velocity on retarget; drag release uses measured gesture
velocity. Initial/dismissal/programmatic/release motions currently share one
profile; a phase-specific motion seam remains a follow-up if native evidence
demands it.

## Profile discipline

`IosSheetProfile.ios26` and `.ios27` are independent, explicitly unmeasured
fallbacks. An unknown major version fails instead of silently using27.
`observedPage402x874Profile(26|27)` is a research profile qualified to the
402x874@3x, safe62/34, portrait, keyboard-hidden page scenario with
fixed320+medium+large. It rejects other geometry. Resting medium435.68 and
maximum778 are native samples; native visible large812 includes bottom safe
area. Floating medium469.666667 scales by386/402 to450.973466 points.

Native animation recorder coordinate defects downgraded side/bottom transfer
fits to hypotheses. The research profile marks these as such; it does not claim
dynamic native parity. A corrected trace cohort must replace them. Default
geometry/radius/motion/snap/overdrag/barrier behavior is a fallback, not evidence
of Apple behavior. See `FALLBACKS.json`.

## Public capability scope

Implemented: named medium/large/fixed/fraction/custom detents, initial selection,
programmatic selection and callbacks, semantic controller, modal/nonmodal
threshold, draggable, dismissible, independent interactive-dismiss lock,
content interaction, keyboard resize/overlay choice, opaque styling, arbitrary
shape/inset/scale/profile resolvers, frame capture and transition hooks.

Not accepted or complete: native page/form/content sizing adaptation, native
edge attachment/preferred width/source-view/27placement API, default grabber
geometry, dynamic content retarget, Reduce Motion, keyboard synchronization,
native presenter transform/stacking, exact gesture arbitration/physics,
phase-specific motion, full interruption semantics, or native accessibility
dismiss policy. These are explicit gaps, not inert option flags pretending to
support the corresponding UIKit APIs.

The playground exposes implemented settings and calibration, short/long scroll,
keyboard and horizontal pager content. Its optional debug overlay is research
UI; normal sheet content does not contain implementation diagnostics.
