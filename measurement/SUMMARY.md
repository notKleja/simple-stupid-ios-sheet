# Measurement + parity handoff

Branch `test/parity-harness`; source commits `bb95157`, `d6e863d`, `3ad0c1c`.
No native/Flutter app implementation edited. Stable contracts:
`measurement/CONTRACT.md`, `schema/{trace,evidence,gesture}.schema.json`.
JSONL v1: one session header, integer monotonic `t_ns`, increasing `seq`, named
event occurrences, flat dotted numeric `metrics`, exact categorical `state`.
Unknowns remain explicit; actual native records ingest without adapters.

## Implemented / verified

- `analysis/compare.py`: event alignment; native-grid interpolation without
  extrapolation or duration normalization; observed phase windows; abs/RMS/max,
  final/velocity/settling-dwell errors; exact states/events; metadata/gap checks.
  Diagnostic subsets/looser targets cannot earn full-profile eligibility.
- `fit.py`: conditional underdamped-grid fit and transfer OLS; not spring truth.
  `inspect_trace.py`: ingestion QC. `spacing.py`: reproducible native hypothesis
  checks retaining anomalies and unavailable samples. `regression.py`: hashed
  runtime pairs, independent trials, geometry bindings and frozen holdouts.
- Matrix: 31 cases × 2 OS × 2 geometry × 2 orientation = 248 cells, ≥10 trials;
  eight adversarial families. Macro-case subconditions remain separately required.
- **34 synthetic regressions pass**, 13 JSON documents parse, whitespace clean;
  source graph refreshed AST-only. Synthetic tests prove math/rejection only.

RMS=`sqrt(mean((candidate-native)^2))`; velocity=`delta_position/dt`; timing
goal=one declared native frame. ≥10 independent trial statistics feed conservative
Welch/Student-t mean uncertainty. Noise never automatically expands targets.
Detailed commands/formulas/limitations are in `analysis/README.md`.

## Recorded relationships — provisional, not accepted trajectories

Hashed real inputs/results: `artifacts/analysis/native_spacing_*.json`.
Ten simulator trials each: 26.4.1/23E254a and 27.0/24A434, 402×874.
Let `W=402,I=8,M=469.6666666666667,L=812`,
`H=height/(width/W)`, `extent=H/L ∈ [0.5784072249589491,1]`:

- Side `x=I*(L-H)/(L-M)` agrees both directions/OS to arithmetic precision.
- Legacy iOS26 bottom `b=x+((L-M)/W)*x*(1-x/I)`; legacy iOS27 downward `b=x`.
  These are **recorder-output hypotheses**, not approved OS-specific behavior.
- Native sibling confirmed ancestry/partial-state sampling errors. Latest
  coherent iOS27 still has ten unavailable detent samples plus ten single-frame
  `y=0,bottom=62` anomalies; report remains unresolved. No samples were trimmed.
- Second geometry: ten actual vPhone26.6.2/23G90 trials, 430×932,
  `W430,M504,L873,I8`; 1887 observed detent frames fit side/quadratic-bottom
  relationships without flagged anomalies. Independent calibration remains open.

Tiny residuals are shared-pipeline consistency, not optical accuracy. Domain is
programmatic medium↔large only; free drag, below-domain behavior and other
configurations cannot inherit these formulas. Presentation bottom spacing is
signed `screen_height-y-height`, not constant8 while the sheet enters.

## Blockers / next decision

No actual Flutter pair supplied: **FAIL, 0 accepted pairs, 248 unresolved cells**.
Radius/contour, barrier alpha, resolved frame metric, hit testing, scroll ownership,
keyboard, stacking, replay delivery and displayed-frame pacing are unestablished.
Second geometry covers iOS26 only. No native spring constants accepted.

Next: calibrate the remaining iOS27 sampler anomaly; collect matched Flutter
trials with fresh visible boundaries; replay frozen holdouts. Master decision:
which phase-specific full profiles and independent shape/hit-test evidence close
acceptance. Changed areas: `measurement/`, `analysis/`, `spec/test_matrix.json`,
`artifacts/analysis/`, generated `graphify-out/` (caches/backups ignored).

## PR #19 fix round 1

All four review findings reproduced with failing regressions and corrected.
Comparison commit: `a52b2db`. Union-grid metrics now count candidate-only spikes
(100pt at8ms yields max100pt, velocity max12500pt/s). Environment changes are
rejected before filtering; exclusions are limited to approved probe markers;
baseline semantic fields remain mandatory. Schema-driven nested validation
rejects malformed sizes/scale/environment and missing/invalid runtime provenance.

Matrix trials now require every pinned phase/check and Cartesian subcondition:
248 cells, 1480 required checks, ≥10 complete independent trials each. Opening
alone is PARTIAL; caller idle windows cannot replace dismissal windows. Required
parameters must match both run headers and frozen recipe preconditions.

Fresh full suite: **54 tests, zero failures/errors** (20 new test methods plus
table-driven malformed metadata cases). Empty manifest remains FAIL/0 accepted,
248 unresolved. Fixtures, including simulated runtime markers, are explicitly
synthetic and prove gates only. No native/Flutter branches were edited.
Concerns: older traces without runtime_kind now fail; most parameterized checks
need observed check markers/parameters before coverage; union RMS is cadence-
weighted; optical calibration and full native parity remain separate evidence.
Exact JSON semantics also preserve boolean/number distinctions in event payloads,
configuration and states (False must not match0; True must not match1).
