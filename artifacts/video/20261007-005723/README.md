# Synchronized iPhone 17 Pro comparison

Left: native UIKit reference. Right: Flutter `StupidSimpleIosSheetRoute`.

- Both simulators: identity-validated iPhone 17 Pro
- Runtime: iOS 26.4.1 (23E254a)
- Languages: English/LTR and Arabic/RTL
- Shared absolute-clock timeline: `measurement/scenarios/synchronized_bilingual_demo.json`
- Selected timeline and both bundled copies: SHA-256 `1e9953160490c23dc99f62c2db6d18a3f221823ee14171c48704ccb1cda63617`
- Recording start delta: 1.829916 ms
- Both apps wrote matching armed and completed acknowledgements
- Composite: 2412×2622 H.264, 78.168333 seconds

Visible scenarios include medium/large page fluidity, custom-height resizing,
programmatic long-list scrolling under both content-interaction policies,
undimmed/modal and dismissal-lock configuration, a component gallery with
matched state changes, and matched Arabic RTL controls.

Persistent implementation, scene, and elapsed-time labels appear inside both
apps and within presented sheets. This video is a visual demonstration. It does
not replace runtime traces or the numerical parity analyzer. Programmatic
scrolling is not finger-driven scroll-handoff proof, and the dismissal-lock
scene is configuration-only because no dismissal gesture is injected.
