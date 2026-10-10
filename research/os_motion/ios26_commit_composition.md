# Commit and cleanup composition — blocked

The complete window-y law remains unresolved, with zero promoted phases and
no fitted or visual curves. The current unsealed Task 2A runtime cohort is
excluded. The original authenticated Task 1/2 evidence remains unchanged.

The exact 23G90 binaries now bind eight additional static functions through
`ios26_commit_function_evidence.json` and `ios26_commit_disassembly.txt`.
Recovery validates their complete nlist extents, file/image offsets, symbols,
UUIDs and instruction-byte SHA-256 against the exact UIKitCore/QuartzCore
binaries, and pins both evidence files independently of any supplied profile.

The previously authenticated `Layer::commit_animations` at 0x183fa846c calls
`setBeginTime:` at +516 and +696 after mapping commit-layer timing. The getter
at 0x183f71354 and setter at 0x183fad528 both use attribute 0x41 and value type
0x12. `animationForKey:` at 0x183f79b6c resolves the model layer and searches
the installed keyed animation list under the transaction lock. Discrete
installed-object snapshots therefore preserve assigned beginTime independently
from the observer's media timestamp; no next-runloop timestamp is substituted
for the epoch.

`removeAnimationForKey:` at 0x183f708ec searches the keyed installed list,
marks deferred removals or unlinks matching entries, schedules stop callbacks,
updates the animation list and marks the transaction. `removeAllAnimations`
at 0x183f7ab80 and `Context::remove_animation` at 0x183fd5b3c supply additional
cleanup provenance. The short UIKit nil-animation stop function at 0x18923b654
and UIView removal function at 0x18916b050 are bound static context; they do
not prove a sheet-specific terminal presentation commit.

Host pairing contracts preserve immutable pre-forward, post-forward and
deferred records by run/layer/install identity, verify unchanged construction
fields in installed copies, reject zero assigned epochs, and distinguish
explicit removal from retained copies. The checked affine point/Jacobian
utility rejects incomplete, reordered, perspective, flipped and unresolved
3D paths. It is a mathematical utility; private additive transform selection
and sheet/controller identity remain prerequisites for production mapping.

Exact remaining jobs: private additive CATransform3D interpolation/order;
exact sheet-view/controller ownership; guaranteed coherent post-transaction
model boundary. After completing these, implement Dart, freeze the recovered
profile and implementation, and run post-freeze mathematical and paired runtime
tests. No Flutter/Dart production motion was changed in Task 2A.
