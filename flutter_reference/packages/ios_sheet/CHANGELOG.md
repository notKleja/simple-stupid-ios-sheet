# Changelog

## 0.1.0-dev.2

- Make iOS 26 the sole supported native-reference scope, with strict reference
  resolution and explicit constants. Keep deprecated iOS 27 compatibility APIs
  labeled as unsupported research fallbacks.
- Add `showIos26Sheet` with typed results, navigator selection, route settings,
  semantic detents, and caller-owned controllers.
- Rename the local fork to `ios_sheet_engine` without changing its upstream
  archive identity or MIT attribution.
- Default the candidate to iOS 26 and add a minimal public example, onboarding,
  troubleshooting, contribution guidance, and a fork provenance matrix.
- Preserve evidence truth: the default iOS 26 profile is unmeasured; qualified
  research profiles provide partial evidence and no complete native parity.

## 0.1.0-dev.1

- Introduce the opaque sheet wrapper, semantic detents, controller, profile
  seams, and research capture contracts over the vendored transition engine.
