# Troubleshooting

Start with `IosSheetProfile.ios26` and the public example. It is an unmeasured
fallback using iOS 26 as the only supported native reference. Describe package
behavior and native evidence separately when reporting an issue.

| Symptom | Cause and action |
| --- | --- |
| `Sheet controller is detached` | No route is attached yet, or dismissal has completed. Check `isAttached`; wait for presentation before semantic operations. Keep the controller in the presenting owner's state. |
| `Controller already has a sheet` | The controller is still attached to another route. Use a separate controller or wait for the old route to detach after dismissal; the pop future can complete before exit animation/disposal. |
| `Sheet is covered by another route` / `Sheet is not current` | A pushed route covers the sheet, or it is dismissing. Pop the covering route first; then act on the current sheet. |
| Empty/duplicate/unknown detent ID | Supply at least one detent, unique nonempty custom IDs, and initial/undimmed/selected IDs present in the list. Constructor checks and environment resolution happen at different stages. |
| Invalid detent fraction/height | Fractions must be finite and in `(0, 1]`; resolved heights must be finite and positive. Valid heights above the maximum are clamped. Check custom resolver inputs in the current environment. |
| Capture before layout | Attachment does not mean geometry has been painted. Call `captureFrame` or `snapshotState` after layout/paint, typically in a post-frame callback, and after the sheet surface has been laid out. |
| Fixed-surface presentation interruption rejected | That profile locks retargeting and explicit dismissal during opening. Wait for `onPresented` or `isPresented`. Arbitrary interruption parity is unproven. |
| Qualified profile throws `UnsupportedError` | `observedIos26Page402x874Profile()` requires 402x874 @3x, safe top62/bottom34, portrait, keyboard hidden, and the observed page scenario. Use the fallback for other environments; do not weaken qualification to imply measured coverage. |
| Drag/barrier dismissal is disabled | `dismissible` and `interactiveDismissDisabled` govern interactive dismissal. `controller.dismiss(result)` remains an explicit dismissal path, subject to current-route and opening checks. |
| Helper throws before `.catchError` handles it | `showIos26Sheet` constructs the route synchronously. Wrap the helper call itself in `try`/`catch` or use `try { await showIos26Sheet(...); } catch (...) { ... }`. Not all validation errors arrive through the returned future. |
| External app cannot resolve the engine | Keep the complete checkout; the wrapper has a relative dependency on `../ios_sheet_engine`. Run Pub in the consuming app. Do not substitute the published upstream engine for fork-only seams. |

For advanced trajectory or hit observations, use `StupidSimpleIosSheetRoute`
directly: the helper omits `trajectoryModel` and `onUnderlyingHitObserved`.
Custom `ScrollConfiguration` inside the sheet can interfere with the engine's
scroll boundary detection; retain the default configuration when investigating
handoff issues.

Include Flutter/Dart versions, platform, profile, detents, navigator nesting,
controller lifetime, steps, and the smallest failing test in a report. Label a
host/widget failure, Simulator behavior, and a physical-device/native reference
comparison distinctly. A screenshot or passing test cannot establish complete
native parity. See [contributing](../CONTRIBUTING.md) for check commands.
