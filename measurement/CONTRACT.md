# Trace and replay contract v1

Schemas are in `measurement/schema/`. One JSON object per UTF-8 JSONL line;
one session header first, followed by append-only event/frame records. `seq`
strictly increases and `t_ns` never decreases. Time is integer monotonic
nanoseconds in a single recorder clock domain, not wall time. Input receipt and
display callback timestamps must use that same domain; keep original hardware
timestamps in extra fields with their conversion provenance. Do not rewrite
the trace for alignment. Unknown numeric values are null, with a dotted field
key and reason in `unavailable`; omission means not instrumented.

`scenario_id` is implementation-independent (for example `medium_large.drag`).
The run ID identifies one trial. Capture identical configuration, device,
orientation, content, keyboard, safe area and OS build for a valid A/B pair.
Record actual OS/build; a simulator, virtual device and physical device must
have distinct device metadata (`runtime_kind` extra field). OS 26 and 27 never
share a measured profile. Metadata changes are named events carrying the new
environment; split analyses at these events.

Frames use screen/window logical points, x rightward, y downward, velocity in
points/second, alpha/scale unitless. `metrics` keys are flat dotted strings:

- `sheet.x`, `sheet.y`, `sheet.width`, `sheet.height`, `sheet.visible_height`,
  `sheet.top`, `sheet.bottom`, `sheet.left_inset`, `sheet.right_inset`,
  `sheet.bottom_inset`, `sheet.detent_height`, `sheet.radius`.
- `barrier.alpha`, `presenter.scale_x`, `presenter.scale_y`,
  `presenter.translation_x`, `presenter.translation_y`, `presenter.radius`.
- `finger.y`, `finger.velocity_y`, `sheet.velocity_y`, `scroll.offset`.
- Extend with `sheet.clip.*`, `sheet.safe_top_distance`, `grabber.*`,
  `keyboard.*`, `presenter.anchor_*`, `presenter.transform.m00` … `m33`,
  or `layers.<stable_role>.*`; raw layer names are research extras.

`state` contains exact categorical/boolean observations: `selected_detent`,
`target_detent`, `gesture`, `scroll_owner`, `underlying_hit_test`, `dismissed`.
Alpha is never a substitute for a hit-test observation. A radius is null when a
single scalar cannot describe the shape; store contour/path evidence separately.

Event names include `present.requested`, `present.started`, `present.settled`,
`dismiss.requested`, `dismiss.started`, `dismiss.settled`, `gesture.began`,
`gesture.ended`, `gesture.cancelled`, `detent.requested`, `detent.settled`,
`scroll.handoff`, `keyboard.changed`, `environment.changed`, `target.changed`.
Repeated event names are addressed by zero-based occurrence. Emit the requested
boundary at actual command/pointer receipt, started on first observable motion,
settled from an explicit documented detector, not a guessed delay.

The analyzer aligns the selected real boundary occurrence independently in
each trace. It never optimizes cross-correlation or normalizes duration.
Subsequent event timings are compared relative to that boundary. Interpolation
is linear within observed samples only; gaps, missing required metrics or
incompatible metadata fail closed. No filtered/excluded noise samples disappear
without an explicit report.

Recipes specify absolute offsets `at_ms` from replay start, screen-point
coordinates and command/checkpoint markers. Replay adapters must record actual
input delivery; scheduled timestamps alone do not prove matched gestures.
Assert preconditions before injection; down/move/up have one pointer ID.
Interpolation cadence and coordinate conversion belong in adapter provenance.
Holdout recipes must be frozen before tuning and never promoted to training
without replacing the holdout set.

Every real artifact in evidence has a SHA-256 digest. Synthetic analyzer tests
prove arithmetic and rejection behavior only. They cannot establish native
sheet constants, gesture physics, platform support, or parity acceptance.
