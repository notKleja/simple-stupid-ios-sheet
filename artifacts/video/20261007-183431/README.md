# Integrated synchronized iPhone 17 Pro comparison

Left: native UIKit reference. Right: Flutter `StupidSimpleIosSheetRoute`.

- Integrated source revision: `632944bb7d2ecd928a303d3f2c7a11fc8f481518`
- Runtime: iOS 26.4.1 (`23E254a`)
- Devices: two identity-validated iPhone 17 Pro simulators
- Timeline: 11 contiguous scenes, English/LTR and Arabic/RTL, 66 seconds
- Timeline SHA-256: `1e9953160490c23dc99f62c2db6d18a3f221823ee14171c48704ccb1cda63617`
- Both bundles: matching clean-build revision and timeline provenance
- Both apps: matching armed and completed acknowledgements
- Composite: 2412×2622 H.264, constant 60 fps, 68.533333 seconds
- Composite SHA-256: `7e4807a8b502d28630307d98d2fa26334973f4b13320bb1bd5fbe74b6bfc16c2`

The playlist demonstrates page-sheet motion, custom-height resizing,
programmatic long-list scrolling, modality/dismissal-lock properties, matched
component state changes, and Arabic RTL presentation. First/final visible
markers provide affine alignment; the in-app clocks remain visible.

This is visual demonstration evidence. It is not numerical parity, native
finger handoff, accepted rendered-contour tolerance, or physical-device
input-to-photon evidence. Native dynamics thresholds, true keyboard behavior,
native stacking/adaptivity/accessibility cohorts, contour noise/correspondence,
and physical-device pacing remain unresolved.
