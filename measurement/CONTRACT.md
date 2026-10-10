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
have explicit `device.runtime_kind` (simulator, virtual_device, physical_device,
or synthetic). Runtime evidence cannot use synthetic provenance. OS 26 and 27 never
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

The analyzer validates nested metadata against the declared schema and aligns
the selected real boundary occurrence independently in
each trace. It never optimizes cross-correlation or normalizes duration.
Subsequent event timings are compared relative to that boundary. Numerical
errors use the union of both observed grids inside the evaluation window.
Interpolation is linear within observed samples only; gaps, missing required metrics or
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

Full matrix coverage requires every declared phase/check/Cartesian subcondition
within the same independent trial. An entry names `check_id`; its analysis
window is pinned by the matrix. Required scalar `measurement_parameters` must
appear identically in both session configurations and recipe preconditions.
Parameterized/manual checks use actual `check.<name>.started/completed` markers;
the harness must observe those boundaries before that check can pass. A single
passing phase remains partial. Only detent.resolved/batch.completed may be
auxiliary; environment changes and mandatory semantic event fields cannot be
hidden by caller policy.

## Additive v2 four-corner model metrics

`trace-v2.schema.json` permits four independent optional logical-point metrics,
named clockwise: `sheet.radius.top_left`, `sheet.radius.top_right`,
`sheet.radius.bottom_right`, `sheet.radius.bottom_left`. Names are identities,
not interchangeable array positions. Present numeric values must be finite and
nonnegative. Explicit null requires a nonblank `unavailable` reason under that
exact metric key. Omission does not imply zero or equality with another corner.

These values describe model/configuration radii, not a rendered clipping contour.
Keep `sheet.radius` null with reason when no scalar describes the surface; it
cannot substitute for any missing corner, even when configured radii are equal.
Raw native geometry-probe values still need a reviewed adapter/provenance before
canonical pairing; this contract does not rewrite or promote those diagnostics.
Historical v1 schemas, artifacts and reports remain byte-immutable.
