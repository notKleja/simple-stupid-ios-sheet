# Synchronized iPhone 17 Pro comparison

Left: native UIKit reference. Right: Flutter `StupidSimpleIosSheetRoute`.

- Device on both sides: iPhone 17 Pro
- Runtime: iOS 26.4.1 (23E254a)
- Languages: English/LTR and Arabic/RTL
- Shared absolute-clock timeline: `measurement/scenarios/synchronized_bilingual_demo.json`
- Recording start delta: 8.1705 ms
- Application launch-command delta: 0.298625 ms
- Composite: 2412×2622 H.264, 74.01 seconds
- Feature source commit: `d34a269d1f4ab8cfb971edc6c578e778d9daddeb`

Visible scenarios include medium/large page fluidity, custom-height resizing,
programmatic long-list scrolling under both content-interaction policies,
undimmed/modal and dismissal-lock properties, a component gallery, and matched
Arabic RTL examples.

This video is a visual demonstration. It does not replace runtime traces or
the numerical parity analyzer. Programmatic scrolling is not finger-driven
scroll-handoff proof, and property labels alone do not prove hit testing.
