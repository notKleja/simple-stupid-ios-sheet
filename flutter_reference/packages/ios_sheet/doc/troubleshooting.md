# Troubleshooting

Start with `IosSheetProfile.ios26` and the public example. It is an unmeasured
fallback using iOS 26 as the only supported native reference. Describe package
behavior and native evidence separately when reporting an issue.

| Symptom | Cause and action |
| --- | --- |
| Detached readiness wait / `Sheet controller is detached` | Call `whenPresented()` after attaching through the helper/route. While detached it returns a future that fails asynchronously with `StateError`; it does not throw from the call or queue for the next attachment. Handle it with `try { await controller.whenPresented(); } catch (...) { ... }`. Semantic selection/dismissal commands still reject a detached controller synchronously. |
| `Controller already has a sheet` | Await `controller.whenDetached()` before reuse, or use a separate controller. It captures the current attachment and succeeds only after actual route disposal clears it. Navigator's pop-result future can complete during exit while the controller is still attached. An already-detached live controller completes this wait asynchronously without another frame. |
| `Sheet is covered by another route` / `Sheet is not current` | Covering cancels an outstanding `animateToDetent` outcome to `false` without detaching or stopping engine motion. Uncovering does not revive that outcome; accept a fresh request once current. `whenPresented()` is latched engine readiness, not current-route visibility; a covered opening may settle, or muted tickers may defer it. |
| `animateToDetent` completes `false` | Its request was superseded (including by legacy selection or the same ID), acquired sheet drag ownership, was covered/dismissed/logically removed/detached/disposed, or failed the owned semantic-rest check. An accepted command during an already-active sheet drag also returns `false`. This does not roll back accepted selection or stop underlying motion; an old request cannot later become `true`. |
| Empty/duplicate/unknown detent ID | Supply at least one detent, unique nonempty custom IDs, and initial/undimmed/selected IDs present in the list. Constructor checks and environment resolution happen at different stages. `animateToDetent`, like `selectDetent`, throws validation/construction failures synchronously; a rejected request does not supersede an older accepted request unless user code reentrantly accepted a newer command. |
| Invalid detent fraction/height | Fractions must be finite and in `(0, 1]`; resolved heights must be finite and positive. Valid heights above the maximum are clamped. Check custom resolver inputs in the current environment. |
| Capture before layout | Attachment and `await whenPresented()` describe engine lifecycle, not a final paint receipt. Call `captureFrame` or `snapshotState` after layout/paint, typically in a post-frame callback, and after the sheet surface has been laid out. No lifecycle future certifies compositor pixels or native parity. |
| Fixed-surface presentation interruption rejected | That profile locks retargeting and explicit dismissal during opening. Await `controller.whenPresented()` after attachment before issuing those commands. An accepted removal before readiness fails that wait asynchronously; a rejected opening command does not mark presentation removed. Arbitrary interruption parity is unproven. |
| Selection rejected while still attached after removal | Logical removal is terminal before physical detachment. New selection is rejected after committed completion, even if `isAttached` remains true during exit. Await the captured attachment's `whenDetached()` for safe reuse. |
| Lifecycle wait fails after owner disposal | Disposing an attached controller fails pending `whenPresented()`/`whenDetached()` with asynchronous `StateError`, resolves pending detent outcomes `false`, and severs observation. It leaves the route owned by Navigator; disposal does not falsely fulfill actual route detachment. Calls after disposal also return failed lifecycle futures, and the controller cannot be reused. Schedule disposal outside its own `notifyListeners` stack. |
| Canceled sheet drag unexpectedly returns open | Cancel releases gesture ownership and snaps a live route open with zero release velocity, excluding the closed target so cancel never dismisses. If no configured detent above zero exists, the fallback still keeps the live route open without popping. Popped/disposed/detector-teardown cancellation only clears ownership and starts no motion; normal release behavior is unchanged. The interrupted awaitable selection remains `false`. |
| Qualified profile throws `UnsupportedError` | `observedIos26Page402x874Profile()` requires 402x874 @3x, safe top62/bottom34, portrait, keyboard hidden, and the observed page scenario. Use the fallback for other environments; do not weaken qualification to imply measured coverage. |
| Drag/barrier dismissal is disabled | `dismissible` and `interactiveDismissDisabled` govern interactive dismissal. `controller.dismiss(result)` remains an explicit dismissal path, subject to current-route and opening checks. |
| Helper throws before `.catchError` handles it | `showIos26Sheet` constructs the route synchronously. Wrap the helper call itself in `try`/`catch` or use `try { await showIos26Sheet(...); } catch (...) { ... }`. Not all validation errors arrive through the returned future. |
| External app cannot resolve the engine | Keep the complete checkout; the wrapper has a relative dependency on `../ios_sheet_engine`. Run Pub in the consuming app. Do not substitute the published upstream engine for fork-only seams. |

All lifecycle future observers run asynchronously. Each wait belongs to the
attachment captured at the call; later reuse cannot change its outcome.
Detachment observers run after synchronous detach listeners and `onDismissed`
have returned or thrown. Error message strings are diagnostic text; handle
`StateError` by lifecycle meaning rather than parsing those strings.

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
