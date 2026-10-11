# Changelog

## 0.1.0-dev.3

- Add `whenPresented()`, `whenDetached()`, and `animateToDetent(String)` to
  `IosSheetController`. Lifecycle waits capture the current attachment, deliver
  observers asynchronously, and never bind to a later sheet. Detached
  `whenPresented()` fails asynchronously with `StateError`; `whenDetached()`
  succeeds at real route disposal, not Navigator pop-result completion.
- Awaitable selection returns `true` only for its owned semantic rest, and
  `false` on coverage, sheet drag ownership, supersession, dismissal, logical
  removal, detachment, or disposal. Validation/construction errors remain
  synchronous; the validated already-resting shortcut needs no extra frame.
- Retain iOS 26 as the sole native-reference scope and the default profile as
  an explicitly unmeasured fallback. These futures describe engine lifecycle,
  not final paint receipts, compositor pixels, or accepted native parity.

### Legacy behavior deltas and compatibility

1. Attached-controller disposal now severs observation and prevents later
   use-after-dispose route notifications. It leaves route ownership with
   Navigator and settles pending lifecycle waits with `StateError` and detent
   outcomes `false`; ordinary `ChangeNotifier` disposal constraints still apply.
2. Reentrant selections/dismissals suppress stale outer selected callbacks and
   ownership-unsafe rollback. A newer accepted command survives instead of
   having its semantic state overwritten by an outer failing/superseded call.
3. Selection is rejected after logical removal has committed, even while the
   old route/controller remains physically attached pending disposal.
   `didComplete` makes that removal state explicit.
4. If `super.didPop` declines a pop before logical completion, provisional
   dismissal flags/target/extent are rolled back while that attempt still owns
   them. Rejection does not falsely mark pending presentation removed; already
   committed completion or physically interrupted ticker effects are not undone.
5. Generic engine drag cancellation now finalizes gesture ownership and snaps
   a live route to a configured detent with zero release velocity. The closed
   target is excluded only for cancel, so cancel never dismisses; with no
   configured detent above zero, the fallback still settles the live route open
   without popping. Popped/disposed/detector-teardown cancellation only clears
   ownership and starts no motion. Normal release inputs/`includeClosed` policy,
   resistance equations, and snap resolver math are preserved. This affects
   controller-less generic engine routes as well as the wrapper.
6. **Source compatibility break:** classes using `implements IosSheetController`
   must implement the three new methods. Ordinary callers and subclasses that
   inherit implementations retain the existing synchronous `selectDetent` and
   `dismiss` signatures; an additive symbol set does not preserve every
   implementer's source compatibility.

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
