# Synchronized iPhone 17 Pro comparison

Left: native UIKit reference. Right: Flutter `StupidSimpleIosSheetRoute`.

- Both simulators: identity-validated iPhone 17 Pro
- Runtime: iOS 26.4.1 (23E254a)
- Languages: English/LTR and Arabic/RTL
- Shared absolute-clock timeline: `measurement/scenarios/synchronized_bilingual_demo.json`
- Selected timeline and both bundled copies: SHA-256 `1e9953160490c23dc99f62c2db6d18a3f221823ee14171c48704ccb1cda63617`
- Recording process start delta: 1.8005 ms
- Both apps wrote matching armed and completed acknowledgements
- Completion acknowledgement delta: 4 ms
- Composite: 2412×2622 H.264, constant 60 fps, 68.516667 seconds
- Composite SHA-256: `b8ffb22b8df31d479170a7ee4e3ddde1af5c0a95527385ac51a098dd3b12cba5`
- First and final visible markers drive affine time alignment; no artificial pre-roll is used

Visible scenarios include medium/large page fluidity, custom-height resizing,
programmatic long-list scrolling under both content-interaction policies,
undimmed/modal and dismissal-lock configuration, a component gallery with
matched state changes, and matched Arabic RTL controls.

Persistent implementation, scene, and elapsed-time labels appear inside both
apps and within presented sheets. Sampled post-alignment clock differences were
62 ms at the opening, 26 ms in the English gallery, 9 ms in Arabic resizing,
and 4 ms at the final marker.

This video is a visual demonstration. It does not replace runtime traces or the
numerical parity analyzer. Programmatic scrolling is not finger-driven
scroll-handoff proof, and the dismissal-lock scene is configuration-only
because no dismissal gesture is injected.
