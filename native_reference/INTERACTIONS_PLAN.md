# Phase2 native interaction probes

Authorized scope: deterministic nonmodal hit testing and scroll/sheet handoff,
CLI/XCUITest/vPhone only; ten independent trials per accepted cohort. No Flutter
behavior is implemented and no gesture law is inferred from package defaults.

Nonmodal probe: a real presenter UIButton records control activations. Replay
the same measured background point at medium, large, then medium. Record actual
window touch delivery/hit view and control outcome; alpha is not an interaction
oracle. The background point must remain outside the sheet's content bounds in
the exposed state. A cached location is used when UIKit hides background AX.

Scroll probe: native UIScrollView with known2400pt extent, starts at observed
top offset, and two public scroll expansion policies. Replay one identical
vertical content drag with explicit timing. Capture delivered finger samples,
UIScrollView offset/pan state, sheet geometry and all available pan recognizer
state/translation/velocity. Movement-consumer classification is explicitly
derived; private gesture ownership stays unavailable unless directly observed.

XCUITest drives simulator trials; the existing vPhone API is a separate replay
adapter whose actual delivery must be verified. Each run declares scenario,
trial, attempt, training/holdout role, exact OS/device configuration and terminal
outcome. Raw failures and missing observations remain stored. Frozen recipes
and manifests link source revision, raw bytes and SHA256.

Release/overdrag experiments start only after these two probes yield stable,
reviewable cohorts. Any unavailable runtime/action or failed precondition remains
unresolved; no tolerance is loosened to obtain acceptance.
