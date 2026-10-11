# Controller lifecycle futures — approved design

Status: approved by the human on 2026-10-11 after Opus review cleared the four document corrections. All five design decisions in section 11 are approved. This tracked design is the frozen implementation contract; the design approval gate is satisfied. Product behavior is specified here but is not yet implemented or runtime-verified. Promotion preserves the approved content and adds Opus's final nonblocking engine-cancel acceptance requirement: a live route with no configured detent above zero must still settle open without popping.

Frozen base: `feat/ios26-package-dx` at `9f70e231974b0b6f7a1b542db6bfcbe68924c9e2`. Current inspected checkout HEAD matches that SHA and tracked status was clean. Authoritative inputs: Opus plan `/Users/kleja/.claude/plans/the-user-has-explicitly-partitioned-thunder.md`, `w0-i1-hooks.md`, `w0-i2-test-recipes.md`, and the controller/route/engine source at that SHA. Installed framework source is Flutter 3.44.6; the findings do not certify other framework versions or native parity.

## 1. Intent, scope, and selected approach

Add three methods to `IosSheetController` so callers can await first presentation, actual controller detachment, and the outcome of a semantic detent selection. Preserve `selectDetent(String)` and `dismiss([Object?])` signatures, accepted-selection getters, and ordinary nonreentrant callback/ChangeNotifier delivery. The legacy edge-case behavior deltas in section 9 are explicit approval scope, rather than an assertion that every existing execution path stays unchanged. Completion concerns engine lifecycle, not a final paint receipt, compositor pixels, or UIKit equivalence.

This also proposes an explicit generic engine behavior change: canceled sheet drags release gesture ownership and snap to a detent when the route is live. It affects generic engine routes, including routes without an IosSheetController. Engine teardown cancellation only releases ownership and never starts new motion. The cancel fix has its own first implementation commit and engine regression tests, before the private bridge or wrapper future implementation. Normal release inputs, resistance equations, and snap-target math are preserved. Human approval must include this behavior change; it cannot be described as observational bookkeeping.

Use explicit attachment records and operation identities, reduced by concrete lifecycle events. Keep first-presentation and actual detachment separate from detent motion and coverage. Use normal asynchronous `Completer` instances, plus `TickerFuture.orCancel` for motion ownership; do not poll listeners, add timers, use `Completer.sync`, or await plain canceled ticker futures.

Alternatives considered:

| Approach | Assessment |
| --- | --- |
| Infer everything from controller listeners | Reject: attachment, drag start, coverage, pop entry, and logical removal do not all notify at the frozen base. Canceled ticker futures can remain pending. |
| Public/protected engine lifecycle hooks | Defer: inherited hooks enlarge the public wrapper API beyond the three requested additions. The existing extractor includes engine-declared inherited members. Requires separate API-scope approval. |
| Explicit route events plus a nonexported fork-private engine bridge | Selected. Precisely observes drag ownership and validated programmatic start without adding public inherited members. This jointly maintained path dependency already requires the local engine fork. Cleanup and direct bridge tests are mandatory. |

The lead has ruled that the public wrapper addition budget stays exactly three and that the narrow internal bridge is preferred, provided it unregisters reliably, leaks no global state, and receives direct coverage. That ruling constrains architecture; all public semantics below still require approval of this draft as a whole.

## 2. Public API and normative documentation

These are methods, not getters. They are non-`async` entry points so command validation remains synchronous where specified.

```dart
/// Waits for the currently attached sheet's first settled presentation.
///
/// Captures the attachment that exists when called. Completes successfully
/// once that sheet first rests at a configured detent with no active animation
/// or sheet drag. Presentation is latched for the attachment: later detent
/// motion or coverage does not reset it. This is engine readiness, not a
/// guarantee that final geometry has painted or that this is the top route.
///
/// If already presented, completes without requiring another frame. If
/// detached or disposed, returns a future that fails with StateError; the
/// call itself does not throw. If removal is accepted before presentation,
/// or this controller is disposed while waiting, the future fails with
/// StateError. It never waits for a future attachment or rebinds after reuse.
/// Future observers always run asynchronously.
Future<void> whenPresented();

/// Waits until the currently attached sheet releases this controller.
///
/// Captures the attachment that exists when called. Completes at route
/// disposal after the attachment is cleared, not when Navigator's pop-result
/// future completes. Coverage and accepted dismissal alone do not detach.
/// If already detached, completes without requiring another frame. A later
/// attachment does not change the captured future's outcome.
///
/// Disposing this controller while attached fails this wait with StateError;
/// controller disposal does not claim that the route has finished disposal.
/// Calling after controller disposal also returns a failed StateError future.
/// Future observers run asynchronously, after synchronous detachment
/// listeners and onDismissed have returned or thrown.
Future<void> whenDetached();

/// Accepts the same semantic detent selection as selectDetent and waits for
/// its outcome.
///
/// Selection getters and selection callbacks update synchronously. Returns
/// true only if this request remains current, its animation finishes without
/// cancellation, and the sheet rests at the requested semantic identifier.
/// A fully validated already-resting request succeeds without starting a
/// ticker or requiring another frame.
///
/// Returns false when superseded by another accepted selection, interrupted
/// by sheet drag ownership, covered, dismissed, logically removed, detached,
/// or disposed. False does not roll back selection or stop underlying motion.
/// A request accepted while the sheet already owns a drag returns false.
///
/// Throws synchronously for the same validation/construction failures as
/// selectDetent: detached/disposed controller, unknown identifier, fixed
/// opening lock, noncurrent/removing sheet, and trajectory construction or
/// validation failure. A rejected request does not supersede an accepted
/// request unless user code reentrantly accepted another command first.
/// Equal-height detents remain distinct semantic identifiers. Future
/// observers always run asynchronously. Completion does not guarantee paint.
Future<bool> animateToDetent(String identifier);
```

The public controller class documentation must also state disposal ownership: supplied controllers remain caller-owned; disposing an attached controller severs controller observation, settles its exposed waits, and leaves the sheet route to Navigator. Getters then expose detached defaults, and no route event may notify the disposed controller. Flutter's existing prohibition on disposing a ChangeNotifier from inside its own `notifyListeners` stack remains; schedule that disposal after the callback stack. The feature does not implement deferred ChangeNotifier disposal. Validate that precondition before changing controller ownership: if `super.dispose()` rejects active notification in debug, no partial abandoned/cleared attachment state may remain. Ordinary disposal calls `super.dispose()` once, records disposed, severs the matching route/controller ownership, unregisters the bridge if present, and settles captured old records without notifying listeners. The later route `_changed`/`_detach` calls are guarded no-ops for this disposed controller.

No new exported exception/result types. `StateError` identifies invalid lifecycle waits; callers should not parse message strings. Suggested stable diagnostic messages are `Sheet controller is detached`, `Sheet controller is disposed`, and `Sheet removed before presentation`. Existing synchronous command messages/order remain wherever they already exist.

### Explicit decisions

1. Detached `whenPresented()` returns `Future<void>.error(StateError(...))`; it does not synchronously throw and does not bind to the next route. This follows I2 P1's recommended single asynchronous error channel, rather than I1's optional read-before-show queue.
2. Successful attachment increments a monotonic generation and allocates a new record. Failed double attachment leaves the existing record unchanged. Every captured wait belongs to one record forever.
3. `whenDetached()` means actual route release, not merely Navigator pop completion and not caller controller disposal. Attached disposal therefore fails that wait rather than falsely succeeding.
4. Presentation is first engine rest for the attachment, compatible with the existing `isPresented` latch and predicate. Coverage does not fail it; a covered opening can present if its engine settles. Muted tickers can delay presentation until uncovered. Removing is terminal and blocks presentation success.
5. Coverage immediately resolves a running detent wait to `false`, without canceling engine motion. Uncovering never resurrects that request. A fresh command can be accepted once current again.
6. Every accepted selection supersedes an outstanding awaitable selection, including legacy `selectDetent`, route `selectDetent`, and identical IDs. An invalid/blocked call does not supersede. Lower-level engine motion invalidates the old operation through the start bridge or ticker cancellation.
7. Drag ownership starts cancellation, not pointer-down, first value change, or release. An accepted command during an already active sheet drag returns `false`; adding a new drag-state synchronous rejection would violate the promised select validation behavior.
8. Already-resting animate validates the trajectory/model before its shortcut. This preserves synchronous construction errors even for the same ID. It then resolves `true` without a ticker. Legacy `selectDetent` continues to restart same-ID motion as before.
9. Detent success requires the request's ticker to fulfill `orCancel` successfully and a fresh semantic rest check. The route's value/status reducer alone never declares motion success. If a synchronous final-tick callback supersedes/dismisses the request before the ticker-success handler runs, that request resolves `false`. First presentation, once latched, remains successful even when `onPresented` immediately dismisses.
10. No promise of future object identity, waiter observer FIFO, exact controller notification counts, or frame counts. Multiple waits on one generation get the same outcome; asynchronous observer delivery and the partial order in section 6 are contractual.

## 3. Ownership and internal state

Keep private classes in wrapper `route.dart` (or a private part of the same library if necessary); do not export helper types. Add `dart:async` for Completer. Do not change entrypoints.

```text
Controller: detached | attached(attachment) | disposed
Attachment: generation + route identity + controller ownership
            presenting | presented | removing | detached | abandoned
            presentedEver: boolean latch
            lazy presentation result and lazy detachment result
Route:      independent removing/disposing flags and pop-attempt guard
Motion:     no operation | active operation(token, attachment, semantic ID)
Command:    provisional attempt(serial, attachment, previous IDs/model state)
            -> accepted operation or rejected attempt
Coverage:   independent current/covered state
Drag:       engine-owned flag, observed by private bridge
```

`abandoned` is controller disposal while its route lives. The route's own presentation/callback behavior continues; it retains no controller ownership. A route can have no supplied controller and still use the reducer/callbacks.

Attachment records retain terminal outcome data rather than eagerly creating error futures. Each waiter kind creates at most one normal completer lazily when actually requested. A terminal event with no subscribed waiter records the error/outcome without creating or completing an unobserved failed future. Calls after a terminal state produce the documented completed/failed future for that captured state. There is no pending detached-generation presentation record and no pre-attach queue.

Operations have monotonic request tokens separate from generation and from semantic ID. Same ID, equal geometry, same status, and a later A→B→A do not imply the same request. Every completion path takes the captured record, compares attachment/route/token identity, then uses a once-only settlement helper. Terminal operations release any closure/record references to the controller, route, prior operation, trajectory, and bridge registration as practical. A late ticker handler for an old record can only observe its recorded outcome; it cannot inspect or settle the controller's newer attachment.

## 4. Fork-private bridge and command transaction

Add `packages/ios_sheet_engine/lib/src/controller_lifecycle_bridge.dart`, not exported by the engine entrypoint or wrapper. Engine main library and wrapper `route.dart` import it. Prefix the wrapper import and document the intentional internal dependency; if the analyzer flags `implementation_imports`, suppress only that import with a reason, rather than disabling the lint globally. No exported mixin member, constructor argument, getter, callback field, or result type is added for the bridge.

The bridge registers one immutable callback bundle against route object identity with an `Expando`, returns an idempotent unregister closure, and never enumerates or holds strong global route keys. The callback bundle supports only these events:

- sheet drag start immediately after `_isUserDragging = true`, before external Navigator gesture callbacks;
- coherent sheet drag end/cancel after ownership clears, covering popped, scroll takeover, snap, and overdrag exits;
- validated programmatic-detent start after simulation construction but before `_animationTargetValue`, `_stickingPoint`, and `animateWith` mutate/interrupt motion. The callback can choose proceed or the awaitable already-resting shortcut, or throw if the constructing attempt lost ownership.

Use a registration token: unregister removes only that token's bundle, so a stale unregister cannot erase a later registration. Remove registration on wrapper route disposal and attached controller disposal; existing controller-less routes need no registration. Each wrapper callback also checks live route phase, attachment identity, controller disposal, and registration ownership. Engine route teardown clears its bridge record as a final fallback. A retained callback cannot fire after its registration is invalidated. Expando prevents a registry root from retaining an unreachable route; explicit unregister releases the bundle while a route remains reachable in Navigator.

Direct tests cover register/dispatch/unregister idempotence, registration replacement, stale unregister, absence after teardown, and no dispatch after dispose. Do not expose registry size/debug helpers as production API. Engine integration tests cover callback start/end ordering relative to `isUserDragging` and simulation/start state.

For gesture cancellation, wire `_RelativeGestureDetector.onVerticalDragCancel` through a private relative-cancel callback. Clear `_referenceHeight`, engine drag ownership, and optional Navigator gesture bookkeeping. If the route remains live, settle/snap with the existing resistance/snap resolver and zero release velocity, excluding the closed target for this cancel-only path so cancel returns to a configured detent rather than dismissing. When no configured detent above zero exists, the cancel path must still settle the live route open without popping; this fallback is acceptance requirement G01a. Normal release retains its existing includeClosed policy and inputs. Popped/disposed cancellation must not start another ticker. Detector State.dispose uses a separate private teardown-cancel path that only clears ownership/bookkeeping; it never starts motion, including when widget unmount precedes route.dispose. Clear its local gesture/reference record before invoking a callback so duplicate cancel/unmount is idempotent. This is an explicit generic engine behavior change, independently reviewed in `fix(engine): finalize canceled sheet drags`, with generic-route cancel/unmount and normal-release regression tests. Do not change resistance equations, snap resolver math, or normal release inputs. In the next engine commit, add end/cancel bridge dispatch to this established coherent finalization path so every early return clears ownership before dispatch. The old awaitable operation stays `false` even if canceled drag settles at its original ID. Test real recognizer cancellation and teardown separately from direct bridge tests. Record both the cancel behavior change and private bridge in repository `docs/FORK_PROVENANCE.md`.

E4a owns only engine source/tests and the corresponding fork-provenance documentation in `wt-engine`; it adds no non-underscore member to any engine mixin or route. Public-looking bridge helper names may exist only in the nonexported src library for cross-package use, never as inherited route/mixin members. E4b imports and consumes that bridge later from wrapper source; E4a does not edit wrapper code or rely on the new controller methods for its tests.

### Shared selection ingress

Both controller methods and route `selectDetent` delegate to one private selection transaction. Only animate uses the validated already-resting shortcut. Preserve validation order: controller availability, identifier resolution, opening lock, current/removing check, simulation/model construction. Add removing to the existing `_dismissing` prohibition so a logically completed route cannot accept motion before actual dispose. Do not add a drag rejection to existing synchronous methods.

1. Capture attachment, attempt serial, previous semantic IDs, pre-request resting semantic ID, and motion-model observations. Resolve/validate before touching the accepted-operation record. Provisional semantic IDs can be installed as today so model inputs and engine observers see the requested target, but rollback is ownership-guarded. Register the private bridge after successful attachment and before didPush/any controller status events; failed attachment cannot overwrite another route's registration.
2. Call existing `animateToRelative` and construct/validate its simulation. The creation seam revalidates attempt serial/route phase after arbitrary model code returns and before assigning `_motionRequest`/`_trajectory`. If model code accepted a nested selection, dismissed, detached, or disposed, the outer attempt is invalidated and throws synchronously without restoring nested state or starting an outer ticker. A model failure with no intervening accepted event restores all provisional IDs/model observation fields and preserves the older operation/ticker.
3. At the bridge start boundary, capture a complete operation record and install it before any synchronous engine animation-start status event. Resolve the previous pending operation `false` exactly once. A fully validated already-resting shortcut is permitted only for animate, with no animation/drag/removal/coverage, `presentedEver`, pre-request resting semantic ID equal to the requested ID, and the same rest still true after construction; record immediate `true`, keep accepted IDs, and return a completed engine ticker without changing engine motion. Changing to an equal-height alias uses ordinary motion and semantic rest resolution; provisional target assignment cannot manufacture pre-request alias rest.
4. Otherwise start the ticker and attach success/error handlers to `.orCancel` immediately on return, even if a synchronous callback already superseded the operation. Avoid unhandled cancellation errors and consume the handler chain. If startup throws after actually interrupting old motion, settle the new internal record `false`, preserve any newer reentrant owner, and rethrow; a physically canceled old ticker cannot be restored. This is distinct from rejected construction, which is guaranteed to preserve the old operation.
5. Before emitting explicit selected callback or `_changed`, verify that the attempt remains the owner. Do not emit a stale outer selected event or restore old IDs after a nested callback changes selection. Selection getters still become available synchronously for accepted calls, and ordinary successful nonreentrant calls keep existing selected callback timing/count.
6. An accepted operation already under sheet drag ownership records `false` immediately while preserving the same selection side effects as legacy select. It does not gain ownership by waiting for release.

Direct low-level engine `animateToRelative` with no wrapper attempt conservatively invalidates a pending semantic operation at the bridge start boundary. Other engine methods that replace/set animation cancel the captured `.orCancel`; their exact physical behavior remains the existing engine contract. No detent success may be inferred from a canceled ticker's final matching coordinate.

The bridge callback at the start boundary must not call public listeners or caller callbacks. Guard custom Simulation methods that execute during `animateWith` with the same attempt/token checks; tests cover reentrant trajectory creation, invalid trajectory values, and startup callback retargets. Unsupported pathological Simulation code that mutates Navigator while Flutter is evaluating a tick remains subject to Flutter's own lifecycle constraints; do not catch-and-silence framework errors to manufacture success.

## 5. Route events and exact completion table

Engine value and status notifications both call an idempotent reducer. Preserve semantic synchronization, but after each external callback revalidate captured route/attachment/token before subsequent writes. First presentation may latch only when `isActive`, not removing/disposing, no drag, no active animation, and engine extent matches a configured detent within the existing `1e-6` tolerance. Prefer the requested semantic ID among aliases. Coverage does not add an `isCurrent` requirement to this presentation predicate.

Introduce a provisional pop-attempt guard before delegating to `super.didPop` so reverse-animation synchronous events cannot claim new presentation/motion success. The existing fixed-opening `false` exit occurs before this guard and changes no future. Commit removal and cancel/fail waiters in `didComplete`, which covers accepted pop, `removeRoute`, replacement, and related completion paths. If super returns false without completion or throws before completion, roll back provisional dismissal flags/extent/target only while still owner and clear the attempt guard; do not fail presentation solely for an attempted/denied pop. If super already called `didComplete`, removal remains committed even if later code throws. Ticker cancellation caused by a failed pop attempt still resolves motion `false` because that ticker was physically interrupted; lifecycle presentation can continue and is not falsely declared removed.

`didChangeNext` and `didPopNext` call super, then reduce current/coverage state. A non-null next route/noncurrent live sheet cancels active detent ownership promptly. Losing coverage triggers a fresh presentation eligibility check; it does not recreate canceled motion operations or notify public controller listeners solely because of coverage.

`dispose` is the universal terminal fallback for Navigator teardown. Mark disposing first; invalidate bridge; remove engine value/status handlers; settle pending presentation/motion and detach old generation before calling `onDismissed`. Keep `super.dispose()` in a `finally` so a throwing `onDismissed` cannot prevent framework/ticker teardown. Detachment notification still sees `_route == null` before `onDismissed`, as at the frozen base. Capture old record locally so a listener's reuse cannot be overwritten by later old-route cleanup.

Notation: `P` = this attachment's presentation wait; `D` = detachment wait; `A` = active detent operation. “Error” means asynchronous StateError; “unchanged” preserves existing successful/failed outcome. Every row applies only to still-pending records unless specified.

| Event/call boundary | P | D | A | Required state/timing |
| --- | --- | --- | --- | --- |
| Detached live controller calls whenPresented | Error | n/a | n/a | Does not throw; no next-generation binding. |
| Detached live controller calls whenDetached | n/a | Success | n/a | Async observer; no frame required; later attach cannot revoke. |
| Either wait called on disposed controller | Error | Error | n/a | Does not throw; disposed takes precedence over detached. |
| Successful attachment | Pending if requested | Pending if requested | None | New generation/route identity; no added public attach notification. |
| Failed second attachment | Unchanged | Unchanged | Unchanged | Sync existing StateError; original record untouched. |
| First eligible engine rest | Success | Pending | Pending until owned ticker-success handler | Latch before onPresented; duplicate value/status events are idempotent. |
| whenPresented after latched presentation, even covered/moving/dismissing | Success | n/a | Unchanged | Async observer, no frame/callback replay; attachment still exists. |
| whenPresented after logical removal before ever presented | Error | n/a | Unchanged | No wait for exit animation. |
| Validated already-resting animate | Unchanged | Pending | New true; prior false if pending | No ticker/frame; getters accepted synchronously. |
| Accepted new animate/select, including same ID | Unchanged | Pending | Prior false; new pending or drag-owned false | Commit at validated start, before engine status callbacks. |
| Validation or construction rejected without nested acceptance | Unchanged | Unchanged | Old unchanged | New call throws synchronously; no exposed new future. |
| Model reentrantly accepts newer command, invalidates outer | Unchanged except actual nested events | Unchanged except actual nested events | Newer survives; outer throws | No outer rollback/callback overwrites newer state. |
| Owned ticker success + active/current/nondragging/notremoving, requested semantic rest | Unchanged | Pending | True | Capture token/generation; final extent alone cannot substitute. |
| Owned ticker success but semantic rest/ownership predicate fails | Unchanged | Pending | False | Terminal mismatch; never remain pending after ticker completion. |
| Captured ticker canceled or startup physically interrupted | Unchanged except removal | Pending | False | Consume TickerCanceled; never await plain ticker. |
| Actual sheet drag starts; pointer down alone excluded | Pending if opening | Pending | False immediately | At engine ownership hook before delta; no motion stop added. |
| Drag ends/cancels/scroll takeover | Recheck eligible presentation | Pending | False remains false | Coherent flags; no operation resurrection. |
| Covered by page or second sheet | Pending if not presented; may later succeed | Pending | False immediately | Do not wait for a muted ticker; no detachment. |
| Uncovered | Recheck if pending | Pending | False remains false | New command required for fresh ownership. |
| Fixed-opening rejected dismiss/pop; denied maybePop | Unchanged/pending | Pending | Unchanged unless actual ticker interruption | No terminal removal event. |
| Accepted pop/didComplete | Error if never presented; success latch unchanged | Pending | False | Before returned pop future observer; actual detach deferred. |
| removeRoute/didComplete without didPop | Error if never presented | Pending | False | Logical-removal latch blocks late animation success. |
| pushReplacement of old sheet | Error if never presented | Pending until old dispose | False | Coverage can cancel first; completion/dispose are idempotent. |
| Navigator teardown/dispose without completion callback | Error if unresolved | Success | False | Universal terminal cleanup; do not rely on Route.popped. |
| Attached controller dispose | Error if unresolved | Error if unresolved | False | Mark disposed, abandon/sever controller ownership, unregister; route remains alive. |
| Old-generation dispose/ticker callback after reuse | Old result unchanged | Old result unchanged | Old result unchanged | Cannot touch new attachment/operation. |
| onDismissed throws | Old terminal result unchanged | Success already recorded | False already recorded | Preserve thrown error visibility; super teardown runs finally. |

Future success represents the event at its settlement boundary, not an enduring state guarantee. For example, a controller may be reattached by a detachment listener before an old detach future observer executes; that future still succeeded for the captured old generation.

## 6. Callback and future ordering

Use ordinary asynchronous completers throughout. Required partial orders:

- first presentation: set `_presented` and record P success → existing `onPresented` → final controller notification for that event → P observer microtask;
- accepted selection: accepted getter state → existing selected callback, if the semantic selection changed and this attempt still owns it → explicit controller notification → returned A observer microtask;
- detachment: clear matching controller attachment and record D success/P error/A false → existing detach listener notification → `onDismissed` → superclass disposal in finally → D observer microtask;
- detent motion success: final synchronous animation/callback/listener stack → ticker-success handler validates live identity/rest and records A true → A observer. A synchronous callback's accepted supersession before that handler yields old A false;
- immediate completed/failed waits and already-resting animate: call returns before user observer; `tester.idle()` suffices without a new frame.

Do not introduce extra public notifications at attach, drag start/end, coverage, or removal solely to settle promises. Internal bridge/reducer events suffice. Existing physical engine notifications, selection notifications, and detach notifications continue. Do not pin counts for a transition that emits both value and status.

Guard reentrant `onSelectedDetentChanged`, `onPresented`, and controller listeners. Handle a selected callback that immediately accepts another selection without stale outer notification metadata/rollback. A presented callback that immediately dismisses sees `isPresented == true` and P remains successful. For plain callback exceptions, retain normal error visibility; use narrowly placed `finally` to finalize mandatory state/teardown rather than swallowing callback errors. A pending A that was accepted but whose selected callback throws still owns motion until a real terminal event; tests must catch the synchronous callback error and verify cleanup, not invent a rollback of a ticker already started.

## 7. TDD acceptance matrix mapped to I2 recipes

E1 owns the pre-lifecycle API-budget probe, focused presentation/detachment tests, and controller lifecycle. E4a owns engine-only canceled-drag finalization, private bridge/seams, and engine tests. E4b owns wrapper-only awaitable selection, shared transactions, and wrapper motion tests after E1 and E4a are integrated. E2 independently writes public acceptance tests from this frozen design. Use I2's Probe registry and Harness; register error handlers immediately before pumping or causing a terminal event. Do not await pending operations ahead of pump progress.

| ID | Requirement/test variants | Recipe/source map | Owner |
| --- | --- | --- | --- |
| P00 | Before lifecycle logic, @nodoc dispose/didComplete stubs preserve every frozen wrapper symbol and add none; scratch dartdoc/extractor evidence recorded, no gate/baseline edits | API baseline/compile fixture investigation | E1 |
| G01 | Generic controller-less engine route: acquired drag then recognizer cancel clears ownership and snaps to a configured detent; near-closed cancel must not pop; optional Navigator gesture bookkeeping ends once | A5 recognizer recipe adapted to generic engine | E4a |
| G01a | Opus final nonblocking requirement: when no configured detent above zero exists, cancel must still settle the live route open without popping; verify ownership cleared, route remains attached/live, and settled engine position is open | G01 generic cancel fixture with no positive configured detent | E4a |
| G02 | Generic route: popped/disposed/unmounted detector cancels ownership without a new snap/ticker; cancel followed by unmount is idempotent | A5 cancel + A8 teardown | E4a |
| G03 | Normal generic drag release, scroll takeover, snap and overdrag inputs/outcomes retain existing resistance and target math; every early return leaves coherent ownership | I1 drag end matrix, existing engine regressions | E4a |
| G04 | Private bridge register/unregister/replacement identity, stale unregister, no dispatch after route cleanup; start before delta, end after ownership clear, validated start after construction before mutation | A5 exact-start gap + direct seam tests | E4a |
| G05 | Engine-only bridge commit adds no non-underscore route/mixin member, wrapper surface unchanged, default absent registration preserves engine motion | API extraction + generic engine tests | E4a |
| L01 | Detached P call returns normally, async StateError; detached D async success; no next-attachment binding | P1, I1 attachment | E1/E2 |
| L02 | Opening waits; two P/D subscribers; duplicate value/status settles once; P callback/listener/observer partial order | P2 | E1/E2 |
| L03 | Latched P succeeds without frames/callback replay, including during subsequent snap and coverage | P3 + covered variation | E1/E2 |
| L04 | Unfixed opening accepted dismiss fails P at completion; fixed opening select/dismiss/pop rejection preserves P | P4 dismissal variants, A4 opening | E1/E2 |
| L05 | Opening removeRoute, replacement, tree teardown: P error; onPresented never fires; D waits for real release | P4, D3/A8 variations | E1/E2 |
| L06 | Pop result/token observed before detach; detach listener before onDismissed before D observer | D1 | E1/E2 |
| L07 | D captures old generation; await D then reuse twice; reattach from D observer; failed double attach preserves old waits | D2 + I1 reuse/double attach | E1/E2 |
| L08 | Cover/uncover never detaches; remove covered sheet; typed replacement result and eventual D | D3 | E1/E2 |
| L09 | Covered opening retains P (transparent/nonopaque finite-fixture lets it settle); opaque ticker mute may defer until uncover; cover never resets latched P | P2/P3 + D3 coverage harness | E1/E2 |
| L10 | Attached controller dispose during opening: P/D StateError, detached getters, route still continues/pops, no notify-after-dispose; post-dispose wait calls error | P1/P4 + I1 disposal gap | E1/E2 |
| L11 | Disposed controller cannot reattach; owner teardown during opening/rest/exit settles waits; detached dispose after completed D does not revoke it | D2 cleanup + I1 teardown | E1/E2 |
| L12 | Throwing onDismissed still detaches and disposes ticker/bridge; duplicate/late teardown does not affect reuse | D1/D2, I1 exception edge | E1/E2 |
| M01 | Accepted getters/callback synchronous; A pending in motion, true at semantic rest; P independently succeeds; final callbacks before A observer | A1 | E4b/E2 |
| M02 | Validated already-resting same-ID A async true after idle/no frame/no selection replay; invalid model still throws; legacy select keeps its same-ID motion | A2 + A4 model | E4b/E2 |
| M03 | Animate→animate, animate→legacy select, route select, identical-ID retarget, A→B→A, two commands without pumping; old false exactly once | A3, I1 same-status | E4b/E2 |
| M04 | Detached/disposed command, unknown ID, covered unknown-vs-valid order, fixed-opening lock, dismissing/removing rejection; rejected call preserves old pending A | A4 | E4b/E2 |
| M05 | Model throws/invalid target/start/velocity with old A: IDs/model observations roll back and old A eventually true; no new exposed pending future | A4 controlled model | E4b/E2 |
| M06 | Reentrant model selection/dismiss invalidates outer transaction; no outer ticker or stale rollback; selected callback/listener retarget wins; onPresented dismiss preserves P and cancels A | A3/A4 harness + I1 reentrancy | E4b/E2 |
| M07 | Pointer down does not cancel; actual sheet drag acquisition cancels before release; canceled gesture and detector teardown leave no dragging/ticker/waits; scroll-only gesture does not invent ownership | A5; G01-G03 establish generic engine behavior first | E4b/E2 |
| M08 | Wrapper bridge callback validates controller/attachment ownership; unregister on controller dispose; no route dispatch reaches abandoned controller | G04 direct engine proof + A5 wrapper integration | E4b/E2 |
| M09 | New command during active sheet drag preserves legacy synchronous acceptance/side effects but A immediately false; release at requested ID cannot revive it | A5 extension + A1 acceptance | E4b/E2 |
| M10 | Dismiss via controller/Navigator/barrier/gesture: A false while still attached, D remains pending; rejected maybePop leaves lifecycle unchanged | A6 + P4 rejection | E4b/E2 |
| M11 | Cover with page and second sheet cancels after idle even if ticker muted; uncover no resurrection; fresh A works | A7 | E4b/E2 |
| M12 | Remove before first snap pump, remove mid-snap, covered removal, replacement, Navigator unmount: A false, D success at dispose | A8 | E4b/E2 |
| M13 | Equal-height alias must yield requested resting ID; canceled old coordinate match cannot succeed; old ticker cancellation after reuse does not touch fresh A | A9 | E4b/E2 |
| M14 | Lower-level route engine retarget/value cancellation resolves semantic A false; ticker canceled without value/status cannot leak; successful ticker with wrong rest resolves false | I1 TickerFuture seams, A3/A8 harness | E4b/E2 |
| M15 | Controlled final-tick selected/presented/listener supersession before ticker-success handler causes old A false; duplicate completion cannot later make true | A1/A3, I1 callback reentrancy | E4b/E2 |
| C01 | All three precise typed signatures compile; existing void selection/dismiss signatures still compile; no new wrapper symbol besides the three methods | compile fixture + API gate | E2/lead |
| C02 | Every tracked API probe terminal after unmount, zero transient callbacks/scheduled frame, no unexpected framework exception; normal binding verifies fake timers/microtasks | I2 cleanup registry | All test owners |

L09 tests attachment-level presentation rather than visibility: use a nonopaque cover or controlled finite trajectory plus pump, and assert `isPresented`/P; use an opaque cover only for the separate deferred-ticker case. Do not depend on hidden ticker scheduling accidentally progressing under `pumpAndSettle`.

L10 cleanup cannot call `sheet.dispose()` twice; extend Harness with owner-disposed tracking. L12 deliberately retrieves/asserts the callback exception, then verifies cleanup; its expected exception is not an excuse to leave a ticker or completer alive. L07 callback reuse from synchronous detach listener is a separate adversarial regression only where Navigator permits it; awaited detachment is the documented reuse route.

G04/M08 must combine direct internal dispatch tests (deterministic start-without-delta boundary) with A5 real recognizer acquisition, so a fabricated bridge event alone cannot be claimed as gesture integration proof. G01/G01a/G02 are controller-less generic-engine regressions and must be green in the cancel-fix commit before bridge code or wrapper APIs exist. M07/M09 use real engine `isUserDragging`, not pointer down or guessed geometry. For timer/completer evidence use the probe registry, binding teardown invariants, `tester.idle()`, and bounded pumping; no timeout wrappers that hide abandoned operations, real sleeps, or runAsync. No assertions of final rendered frame/native parity.

## 8. Planned tracked files and responsibilities after approval

All paths below are relative to `flutter_reference` unless stated otherwise. D1 does not edit them.

| File | Responsibility/owner |
| --- | --- |
| `packages/ios_sheet/lib/src/route.dart` | E1 API-budget stubs first, then controller waits/dispose and route removal/coverage/teardown reducer; E4b sequentially adds motion records/shared selection transaction and private bridge consumption. No E4a edit. |
| `packages/ios_sheet/test/controller_lifecycle_test.dart` | E1 then E4b focused red/green wrapper tests. |
| `packages/ios_sheet_engine/lib/src/controller_lifecycle_bridge.dart` | E4a new unexported, bounded registry and dispatch in second engine commit. |
| `packages/ios_sheet_engine/lib/ios_sheet_engine.dart` | E4a generic canceled-drag finalization first; private start/end/cancel dispatch and validated start boundary second. No non-underscore member addition to mixins/routes; unchanged normal release/resistance/snap math. No E4b edit. |
| `packages/ios_sheet_engine/test/controller_lifecycle_bridge_test.dart` | E4a direct bridge ownership/cleanup tests in second engine commit. |
| `packages/ios_sheet_engine/test/controller_lifecycle_gesture_test.dart` | E4a generic cancel/unmount and normal-release regression tests first, then private dispatch/start integration tests second. |
| Repository `docs/FORK_PROVENANCE.md` | E4a documents explicit generic drag-cancel behavior in first engine commit and private fork bridge in second; separate from public wrapper CHANGELOG. No concurrent E3 edit. |
| `packages/ios_sheet/test/controller_lifecycle_acceptance_test.dart` | E2 independent public adversarial acceptance suite. |
| `packages/ios_sheet/test/api_compatibility_compile_test.dart` | E2 three typed method fixtures, retained legacy signatures. |
| `packages/ios_sheet/tool/api_surface.json` | Lead-only regenerated baseline, precisely three method additions. |
| `packages/ios_sheet/README.md` | E3 current version plus await presentation/selection/detachment ownership example. |
| `packages/ios_sheet/doc/troubleshooting.md` | E3 timing rows: detached/readiness, already-attached reuse, fixed opening; document async wait vs sync selection errors and disposal. |
| `packages/ios_sheet/CHANGELOG.md` | E3 dev.3 API notes and repeats every Legacy behavior delta in section 9, including generic engine cancellation and the `implements` source compatibility exception. |
| `packages/ios_sheet/pubspec.yaml` | E3 wrapper version `0.1.0-dev.3`. |
| `candidate/pubspec.yaml`, `packages/ios_sheet/example/pubspec.yaml` | E3 wrapper constraints together to `0.1.0-dev.3`; candidate's own app version remains `0.1.0+1`, example's own version remains `0.1.0`. |
| Workspace `pubspec.lock`, only if Pub updates it | Lead after integration, only necessary local workspace metadata; no dependency version upgrades. |
| Repository `docs/superpowers/specs/2026-10-11-controller-lifecycle-futures-design.md` | Lead-approved/frozen spec copied from reviewed draft; exact date/path can follow repository convention. |

### Mandatory API-budget proof before lifecycle code

E1's first implementation action after the design gate and engine integration is to add only delegating `/// @nodoc` override stubs for `IosSheetController.dispose` and route `didComplete`, with unchanged inherited signatures and bodies that only call super. E1 must not write lifecycle flags/completers/reducers or any new public future method yet. In ignored scratch output, generate wrapper and engine dartdoc and run the existing API normalization/extractor against frozen `9f70e23` baseline. Require zero removals, zero changes, and zero additions for these two stubs plus the integrated private engine commits. Record the symbol diff and warning output in E1's ignored report before proceeding. This proves @nodoc rather than assuming it. It is an uncommitted diagnostic stage inside E1's eventual futures commit, not an extra partially implemented integration commit.

If the scratch proof introduces any extra symbol, produces unusable docs, or cannot maintain the final three-method addition budget, stop lifecycle implementation and route the concrete mismatch to the lead for design correction. Do not modify the checker, add exemptions, refresh the tracked baseline, or use visibility annotations to hide a new callable API. Once the zero-addition stub proof passes, E1 can write lifecycle code and P/D methods. Its resulting scratch additions must be precisely whenPresented and whenDetached; after E4b, the only third addition is animateToDetent. The lead alone regenerates the tracked baseline later. Disposal behavior belongs in controller class docs and troubleshooting. Existing route didChangeNext/didPopNext/dispose are already baseline members.

E4a must add no non-underscore member to any engine mixin/route. Before its private-bridge commit is accepted, generate scratch docs/extractor output and prove zero inherited wrapper additions. Bridge functions/types remain solely in the nonexported src library. These early probes and final generation are all required; a final baseline check cannot substitute for the pre-lifecycle stop gate.

The engine package version remains `1.0.0-dev.4+fork.1` because this is a private jointly consumed bridge, not a new published public engine release. Wrapper dev.3 records its required fork behavior. No publishing/version-floor/dependency update is included.

## 9. Compatibility risks and explicit deferrals

Adding concrete methods remains source-compatible for callers/subclasses that inherit them; classes using `implements IosSheetController` must implement the three new methods. Pre-release dev.3 and CHANGELOG must name this break; “additive-only API surface” does not mean every implementer compiles unchanged. The API-symbol gate does not verify full signatures, so compile fixtures supplement it.

Coverage cancellation, attached-controller disposal handling, prompt removal settlement, generic drag-cancel finalization, and reentrancy rollback guards are deliberate new semantics. Existing `selectDetent`/`dismiss` keep synchronous signatures, validation order, and side effects in ordinary calls; the explicit exceptional-path deltas below prevent an overbroad compatibility claim. The already-resting optimization applies only to animate; selection listeners still report accepted selection, never promise that a surface painted. Failures do not undo newer choices or geometry.

### Legacy behavior deltas

E3 must repeat all six items in the wrapper dev.3 CHANGELOG. They are approval scope even though the public symbol set only grows by three methods:

1. Attached-controller disposal now severs observation and prevents later use-after-dispose route notifications. It leaves route ownership with Navigator and settles the new pending waits as specified, while ordinary ChangeNotifier disposal constraints remain.
2. Reentrant selections/dismissals suppress stale outer selected callbacks and ownership-unsafe rollback. A newer accepted command survives instead of having its semantic state overwritten by an outer failing or superseded call.
3. Selection is rejected after logical removal has been committed, even while the old route/controller is still physically attached pending disposal. `didComplete` makes that removal state explicit.
4. If `super.didPop` declines a pop before logical completion, provisional dismissal flags/target/extent are rolled back while the attempt still owns them. A rejected attempt does not falsely mark pending presentation removed. Already committed completion or physically interrupted ticker effects are not undone.
5. Generic engine drag cancellation now finalizes gesture ownership and snaps a live route to a configured detent with zero release velocity; the closed target is excluded only for cancel so it does not dismiss. Popped/disposed/detector-teardown cancellation only clears ownership and starts no motion. Normal release inputs/includeClosed policy, resistance equations, and snap resolver math are preserved. This behavior affects controller-less generic engine routes and is documented in fork provenance as well as CHANGELOG.
6. Classes that `implements IosSheetController` must add the three new methods. Ordinary consumers and subclasses inheriting implementations retain existing synchronous method signatures; this is nevertheless a source compatibility break for implementers.

The internal bridge couples two private package implementations. Acceptable here because wrapper installation already requires the entire local engine fork and both are tested/versioned in one workspace. It is not a supported public import for consumers, and it is not a reason to claim compatibility with published upstream `stupid_simple_sheet`. A future public engine lifecycle seam requires its own scope/version/API review.

Deferred: typed dismiss results/reasons; replacing boolean outcomes with enums; changing legacy return types; before-attach wait queues; cancellation tokens/timeouts; painting barriers; new public engine hooks; generic engine composition refactor; entrypoint split; Reduce Motion/VoiceOver feature changes; iOS 27 removal; hosted/Git installation; dependency upgrades; releases/publishing/merges; tracked Graphify refresh; native parity claims. Normal push/show and removal/replacement of those pushed routes are covered. Declarative page insertion/`didAdd` and installing this route through `Navigator.replace`/`didReplace` are not newly promised: the unbounded engine upper-bound/copy semantics need separate focused work. `pushReplacement` that removes an existing pushed sheet is mandatory coverage.

## 10. Commit boundaries and verification

After corrected Opus review #1 and human approval, follow this revised schedule, which supersedes the original unsplit E4 ownership/dependency rows in the Opus program. No branch/commit before the gate. Every integration-branch commit must pass analyze and applicable tests. Core agent total becomes **17**: I1, I2, C1, D1, C2, E4a, E1, E2, E3, E4b, R1, R3, R2, A1, V1, X1, F1. Optional Initiative C still has three separate agents, for a maximum of 20 if invoked. Peak remains three concurrent workers plus the lead; do not run both editors on `wt-life` together.

### Worktree and file ownership

| Worktree | Branch | Owner/scope | Integration rule |
| --- | --- | --- | --- |
| `wt-engine` (new sibling under ignored .worktrees) | `wip/lifecycle-engine` | E4a only: engine source/tests and repository docs/FORK_PROVENANCE.md; no wrapper source edits | Never pushed; two green commits cherry-picked by lead in order. |
| `wt-life` | `feat/controller-lifecycle-futures` | Lead integration, then E1, then E4b; sequential editors | Lead integrates engine commits before E1; E4b starts only from integrated E1+E4a. Push only after final gates. |
| `wt-accept` | `wip/lifecycle-acceptance` | E2 public acceptance/compile tests from frozen approved design | Never pushed; expected red until integration after animate commit. |
| `wt-docs` | `wip/lifecycle-docs` | E3 README/troubleshooting/CHANGELOG/version manifests; no concurrent fork-provenance edit | Never pushed; lead cherry-picks last after baseline. |

### Corrected waves and dependencies

| Wave/gate | Agents/actions | Required dependency and output |
| --- | --- | --- |
| 0 | I1 lifecycle hooks, I2 test recipes, C1 CI feasibility | Read-only investigation as original program; outputs already inform this draft. |
| 0b | D1 corrected draft, C2 format/dependency investigation | D1 used I1/I2; preparation wrote only ignored artifacts. Opus #1 re-review and human design approval are complete; this document is promoted as the frozen spec. |
| Human design gate | Lead freezes approved spec/design commit | Explicitly includes generic engine canceled-drag behavior, legacy deltas, private bridge, and the three-method API budget. No implementation on rejection. |
| 1a | E4a in wt-engine; E2 in wt-accept; E3 in wt-docs | All start from frozen design SHA. E4a emits engine cancel-fix then private-bridge commits and reports. E2/E3 depend only on frozen semantics, so may work concurrently. |
| 1a engine review | R1 reviews detached E4a commits as a reused reviewer assignment | Starts when a slot is free; review cancel behavior, generic regressions, bridge cleanup, validated-start ordering, provenance, zero inherited API additions. Route findings to E4a; R1 rechecks fixed engine SHAs. |
| 1b | Lead cherry-picks accepted E4a cancel-fix then bridge commits; E1 works in wt-life | E1 begins after both engine commits are integrated. Its first action is the mandatory scratch @nodoc override API-budget proof; only after that passes may lifecycle implementation begin. E1 commits green P/D and lifecycle tests. |
| 2 | E4b in wt-life; R1 on detached E1; R3 on detached E3 | E4b starts only after E1 exits and both E1+E4a are integrated. E4b edits wrapper source/tests only, consumes bridge, commits animate/transaction/M tests. R1 lifecycle review does not overlap file edits; R3 checks docs and all six legacy deltas. |
| 3 integration | Lead cherry-picks E2; regenerates/commits API baseline; cherry-picks E3 | Acceptance must be green. An implementation failure routes to E1/E4a/E4b by owner; a test misreading routes to E2. Baseline exactly three additions; E3 docs versions coherent. |
| 3 review/probes | R2 reviews E4b and integrated branch; A1 probes detached integrated SHA | R2 checks wrapper transactions plus engine/wrapper interaction. A1 tests teardown/reuse/coverage/reentrancy/cancel paths; no source mutation on integration branch. Opus #2 reviews results and routed fixes. |
| 4 | V1 fresh verification; X1 DX walk; F1 API/compat review | Frozen integrated/fixed SHA after Opus #2. Opus #3 final verdict precedes lead push/stacked PR; no merge. |

Review/fix routing is by file ownership: E4a for generic engine behavior, internal bridge/dispatch, engine tests, and fork provenance; E1 for P/D, attachment/controller disposal and route removal/pop guards; E4b for animate/shared selection/reentrancy and wrapper motion tests; E2 for independent acceptance/compile fixtures; E3 for public docs/version/legacy-delta changelog; lead for baseline/integration. R1 rechecks engine and E1 findings it issued; R2 rechecks E4b/integration findings; R3 rechecks docs. Reuse the same agents via follow-up tasks; do not expand beyond 17 core agents for fixes. After E4b changes shared route.dart, lifecycle fixes must be coordinated with E4b and applied sequentially by the original owning agent. Never ask an engine author to patch wrapper code merely because a test crosses the boundary.

### Green-per-commit integration order

1. Lead: `docs: design controller lifecycle futures` — corrected, approved frozen spec.
2. E4a, lead cherry-picks: `fix(engine): finalize canceled sheet drags` — explicit generic-engine cancel/unmount behavior, independent engine regression tests G01/G01a/G02/G03, and matching fork-provenance change. No private bridge or wrapper futures needed to pass this commit.
3. E4a, lead cherry-picks: `refactor(engine): add private lifecycle bridge` — nonexported bridge, private start/end/cancel dispatch, validated programmatic-start boundary, bridge/integration tests G04-G05, provenance, zero non-underscore engine mixin/route additions.
4. E1: `feat: add controller lifecycle futures` — first record zero-addition @nodoc stub probe, then lifecycle reducer, P/D, disposal/pop/remove behavior, and red→green tests. Stub probe and implementation are one eventual green commit; no partial animate method.
5. E4b after E1+E4a: `feat: add awaitable detent selection` — wrapper-only A, shared selection transaction, semantic/token identities, bridge consumption, and focused M tests. No engine edits.
6. Lead cherry-picks E2: `test: add lifecycle acceptance tests` — independent acceptance and typed compile fixtures, green at integration. Scratch acceptance branch may be red until integration, never pushed.
7. Lead: `test: refresh API baseline for lifecycle futures` — generated baseline with exactly three method additions, zero removals/changes; no checker exemptions.
8. Lead cherry-picks E3: `docs: document controller lifecycle futures` — API docs/version/README/troubleshooting and repeats all six legacy deltas.
9. Routed findings use fresh short `fix: ...` commits by file owner; original reviewers re-check fixes. No amends, attribution trailers, or unrelated changes.

Before claiming a focused task green, record red test failure for the intended missing behavior, the minimal implementation, then passing focused tests plus relevant existing route/motion/show-sheet/engine gesture tests. Do not claim red/green from this draft's static inspection.

V1 fresh detached verification from `flutter_reference`, exactly as the Opus matrix:

```sh
flutter pub get --no-example
bash tool/check_format.sh
flutter analyze --fatal-infos --no-pub packages/ios_sheet_engine packages/ios_sheet candidate packages/ios_sheet/example
flutter test --no-pub packages/ios_sheet_engine/test
flutter test --no-pub packages/ios_sheet/test
flutter test --no-pub candidate/test
flutter test --no-pub packages/ios_sheet/example/test
```

Then from each package generate dartdoc to `build/api_docs`, and from wrapper run:

```sh
dart tool/check_api_surface.dart build/api_docs/index.json ../ios_sheet_engine/build/api_docs/index.json build/api_docs/simple_stupid_ios_sheet/StupidSimpleIosSheetRoute-class.html tool/api_surface.json
```

Finally from `flutter_reference`:

```sh
bash tool/verify_path_consumer.sh "$PWD/packages/ios_sheet"
cmp ../LICENSE packages/ios_sheet/LICENSE
```

Require zero dartdoc warnings; API baseline comparison zero removals/changes and exactly three recorded additions relative to 9f70e23; compile signatures preserved; all existing plus new tests pass; probe registry terminal at teardown; hosted checks pass on stacked PR. Record actual counts and errors, not estimates. R1 verifies engine cancellation and bridge commits independently before E1, then lifecycle disposal/pop guards at E1. R2/A1 specifically review terminal settlement, bridge teardown, pop-vs-detach distinction, final-tick reentrancy, and false-success prevention across the integrated branch. X1 walks README only. F1 verifies all six CHANGELOG legacy deltas, `implements` warning, the early API-budget proof, and final public surface. Opus #2 and #3 precede push/PR; do not merge. No Simulator/native run is necessary to validate this host lifecycle/engine change, and host success makes no native parity statement.

## 11. Human decision summary — Opus review #1

The human approved all five decisions in this exact Opus summary on 2026-10-11:

1. Approve or reject three new controller methods: whenPresented(), whenDetached(), animateToDetent(id) returning bool; no other public additions and existing sync methods unchanged.
2. Semantics: detached whenPresented fails asynchronously and never waits for next sheet; whenDetached means real route disposal, not pop-future completion; covering, dragging, superseding, or dismissing makes animateToDetent false.
3. Explicit engine behavior change: canceled drags release gesture ownership and snap to a detent.
4. Futures use a nonpublic internal engine hook; classes implementing IosSheetController must add three methods; wrapper version 0.1.0-dev.3.
5. Out of scope: typed dismiss results, timeouts, public engine hooks, didAdd/didReplace insertion, accessibility, publishing, native-parity claims.

“Existing sync methods unchanged” in item 1 describes their signatures and ordinary-call behavior. Approval also includes the six explicitly listed exceptional-path Legacy behavior deltas in section 9; it is not a promise that the previously unsafe edge cases retain their old behavior. Item 3 includes the generic engine scope and live-route snap rule; teardown only releases ownership. The full API contract additionally defines attached-controller disposal failures, the validated already-resting shortcut, and final-tick reentrant supersession. These are fixed recommendations in sections 2-6, not unspecified choices left for implementers.

Human approval of the whole design, including item 3, was received on 2026-10-11. Implementation may proceed under the frozen contract. If the human rejects canceled-drag snapping or any other proposed semantic, the lead must revise the corresponding API docs, completion table, tests, dependencies, and commit scope together and return for design review; do not quietly omit the generic engine fix or treat its approval as implied by the private bridge. Public-hook scope expansion remains deferred. No further user choice is necessary when the whole corrected draft is approved.

Self-review: three methods defined with exact types; synchronous vs asynchronous failures distinguished; every attachment/operation terminal event has an outcome; no unobserved lazy-error completers, polling timers, plain-ticker waits, or generation rebinding; accepted vs denied pop distinguished; generic canceled-drag behavior named and independently committed/tested; E4a/E4b source ownership separated; first E1 API-budget proof gates lifecycle logic; six legacy deltas required in CHANGELOG; all behavior mapped to test recipes/extensions; files, versions, worktrees, commit order, 17-agent schedule and reviewer routing specified. Remaining uncertainty is runtime implementation/recognizer integration and actual scratch API extraction, which must be settled by the stated probes, TDD, and adversarial verification after approval.

## 12. Correction log — Opus review #1 BLOCKED verdict

Only this ignored draft was edited for the correction pass. No product implementation or diagnostic API stub was written, no tests/dartdoc were run, and no branch/commit was created. The Opus review source is `/Users/kleja/.claude/plans/the-user-has-explicitly-partitioned-thunder.md`; the lead supplied its exact human decision summary for section 11.

| Review blocker | Draft correction | Evidence/check required after approval |
| --- | --- | --- |
| C1: drag-cancel described as bookkeeping despite generic engine behavior change | Sections 1/4/9/11 explicitly name generic live-route canceled-drag finalization/snap; separate first implementation commit; G01-G03 regressions; repository docs/FORK_PROVENANCE.md assigned to E4a. Normal release/resistance/snap math retained. | Independent green cancel-fix commit with controller-less engine tests and provenance; human explicitly approves item 3. |
| C2: E4 mixed engine/wrapper ownership and dependencies | Section 10 splits E4a engine-only wt-engine and E4b wrapper-only wt-life, defines waves/review routing, 17 core agents, and exact green-per-commit order; section 7/8 owners align. | Lead integrates reviewed E4a commits before E1; E4b starts only after integrated E1+E4a; every commit green, one editor per worktree. |
| C3: undocumented legacy behavior changes | Section 9 lists all six deltas; section 8/10 requires E3 CHANGELOG repetition; R3/F1 verify coverage; exact Opus approval wording is qualified with the exceptional-path scope. | Public changelog contains each delta; targeted legacy regression tests and compatibility fixtures pass. |
| C4: @nodoc/API budget assumed instead of proven early | Section 8 mandates E1 delegating @nodoc override stubs and scratch docs/extractor before lifecycle logic; zero additions required for probe; stop on mismatch; E4a adds no non-underscore route/mixin member and proves zero inherited additions. | Recorded scratch symbol diff/warnings; no checker/baseline exemptions; final additions precisely whenPresented, whenDetached, animateToDetent. |

Correction status: all four requested document corrections were applied and internally cross-checked, Opus re-review cleared the document, and the human approved all five decisions on 2026-10-11. Opus's final nonblocking no-positive-detent cancel case is included as G01a below the generic cancel test. The design gate is satisfied; implementation and its evidence remain separate work.
