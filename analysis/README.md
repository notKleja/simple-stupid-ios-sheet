# Trace analysis

These standard-library Python tools consume the common v1 JSONL contract,
including gzip-compressed traces. Synthetic tests exercise mathematics and
rejection behavior. They never establish native parity.

```sh
python3 -m unittest discover -s analysis/tests -v
python3 analysis/inspect_trace.py artifacts/native/example.jsonl.gz
python3 analysis/compare.py native.jsonl.gz flutter.jsonl --config measurement/profiles/full.json
python3 analysis/regression.py measurement/regression_manifest.json --matrix spec/test_matrix.json
python3 analysis/spacing.py artifacts/native/cohort/*.jsonl.gz --output artifacts/analysis/spacing.json
```

Run from the repository root. Comparison and regression commands exit 0 for
PASS, 1 for FAIL. An empty manifest fails. Ingestion QC is a separate check;
record-format validity does not establish metric calibration or parity.

## Comparison formulas

Let the selected event occurrence be at native `Tn` and candidate `Tc`.
Original timestamps remain intact. Relative sample times are `t = timestamp-T`.
The report's `clock_offset_ns=Tc-Tn` is clock alignment, **not** gesture latency.
Boundary absence fails. Candidate values are linearly interpolated onto the
native sample grid within measured coverage; extrapolation is forbidden.
Durations are never normalized and no cross-correlation minimizes timing error.
An optional `window` selects observed `start_event`/`start_occurrence` and
`end_event`/`end_occurrence` boundaries (end exclusive). Reports retain original
boundary timestamps and explicitly count frames outside evaluation. A measured
candidate predecessor/successor may bracket a native sample; those samples are
observed, not extrapolated. Required samples within the phase still fail when
missing. One passing phase does not establish another phase or whole scenario.

For native value `n_i`, interpolated candidate `c_i`, and `d_i=c_i-n_i`:

- Absolute mean = `sum(abs(d_i))/N`; signed mean = `sum(d_i)/N`.
- RMS = `sqrt(sum(d_i^2)/N)`; maximum = `max(abs(d_i))`.
- Final difference = `abs(d_last)`; verify resting checkpoints separately.
- Velocity = `(x_i-x_(i-1))/(t_i-t_(i-1))` in metric units/second.
  Velocity RMS/max compare those interval slopes on the same native grid.
- Event timing error = `abs((event_c-Tc)-(event_n-Tn))`.
  Initial goal is one native declared frame (`1000/refresh_hz` milliseconds).
- Effective settling diagnostic = first point of the final continuously
  in-band observed suffix relative to the native terminal value. The report
  includes observed dwell. This is not a physical settling claim when the
  recording ends too early, the terminal value is not a true equilibrium,
  or multiple transitions share one window. Analyze one phase at a time.

Discrete state is held between candidate samples. Both sampled values and
collapsed observed transition sequences must match, so a transient wrong target
cannot hide between native samples. Exact semantics use event payload fields
selected by `exact_event_data`; numerical event payloads belong in separately
observed metrics. If the policy is absent, whole event payloads compare exactly.
`auxiliary_events` explicitly excludes probe-only markers, reports their counts,
and cannot exclude the alignment boundary. Event order and occurrences remain
exact for all retained markers. Recorder-specific started/completed names must
be synchronized or explicitly adapted with provenance; never rename a callback
to settled merely to satisfy a test.

Required null/missing values, incompatible OS build/device/configuration,
environment changes, invalid sequence/time fields, nonfinite values, incomplete
coverage and excessive sampling gaps fail closed. A profile names the metric
subset actually evaluated. A diagnostic subset PASS cannot satisfy full
acceptance: full-profile eligibility requires every baseline metric/state at
the original or stricter targets. Omitted fields or looser targets are listed
as `full_acceptance_missing`. Overall project parity remains separate.

## Tolerances and repeat noise

`measurement/profiles/full.json` encodes the user's initial goals, not Apple
constants. `programmatic-geometry.json` intentionally evaluates only observable
geometry. Full profiles need phase-specific windows/rest checkpoints and true
interaction measurements. Do not apply the final dismissal sample as though it
were the resting medium detent. There is no invented velocity tolerance.

Optional noise input maps metric names to `native_trials`, `candidate_trials`,
and distinct `native_run_ids`/`candidate_run_ids`. Each array contains the same
predeclared independent **trial statistic**, not adjacent frames. At least ten
trials are required. Sample variance is `sum((x-mean)^2)/(n-1)`. The mean
difference uncertainty uses `sqrt(s_n^2/n+s_c^2/m)` with Welch degrees of freedom
and a conservative upper envelope of two-sided Student-t critical values.
This assumes independent trials and approximately normal trial-statistic means;
it is not a pixel-noise or per-frame uncertainty model. Report covariance or use
paired trials when runs are coupled. Uncertainty exceeding target precision
fails as unresolved. Targets are never automatically inflated, and no brief
overshoot samples are automatically excluded. A justified alternative tolerance
needs a separate evidence review; this tool does not authorize it.

Callback gaps are quality diagnostics, not proof of dropped displayed frames.
Actual display pacing, first-input-frame latency and raster/UI stalls need
instrumentation that observes those layers.

## Fitting diagnostics

`fit.py` reads one JSON request on stdin. `linear_transfer` estimates OLS gain
and intercept between supplied finger and sheet displacement samples. An
`underdamped_spring` request supplies actual event-relative `times_s`, `values`,
an observed `target`, and explicit bounded `omega_candidates`/`zeta_candidates`.
It conditionally fits:

`x(t)=target+exp(-zeta*omega_n*t)*(A*cos(omega_d*t)+B*sin(omega_d*t))`,
where `omega_d=omega_n*sqrt(1-zeta^2)` and `v0=B*omega_d-zeta*omega_n*A`.

The grid and best/runner-up residuals are reported. The unit-mass equivalent is
`k=omega_n^2`, `c=2*zeta*omega_n`; mass is not identifiable from trajectory alone.
No native spring, confidence interval, critical/overdamped response or piecewise
model is asserted just because one underdamped fit has a small residual.

## Matrix and holdouts

`spec/test_matrix.json` expands 31 cases over OS 26/27, two distinct observed
iPhone geometry roles, and portrait/landscape: 248 required cells, ten repeated
trial pairs per cell. Subconditions, iPad/resizable references and performance
are additionally listed; a macro-case ID does not prove each subcondition was
executed. Inventory must bind two genuinely distinct display sizes.

Manifest paths resolve relative to its directory. Each entry includes
`cell_id` (`26/iphone_a/portrait/programmatic`), integer `trial`, `native_path`,
`candidate_path`, `config_path`, `recipe_path`, and `runtime_input_verified`.
The latter may only be set after independent actual-delivery verification; a
scheduled recipe alone is insufficient. Paths are hashed in the report. A
holdout also supplies its pre-frozen `recipe_sha256`. The runner rejects
synthetic pairs, reused run IDs/trials, incompatible cells and unfrozen recipes.
Its PASS covers the configured trace-pair matrix only; final acceptance still
requires calibration, full subcondition coverage, clean builds and live tests.

`measurement/holdouts.json` defines eight adversarial families. Coordinates must
be bound to observed device/scenario anchors, generated as complete gesture
recipes, then frozen and hashed before tuning. Preserve every actual input
trajectory and command marker in the resulting trace.

## Current native relationship evidence

`artifacts/analysis/native_spacing_ios26.json` and `native_spacing_ios27.json`
were generated from ten real simulator trials per OS. `spacing.py` keeps all
timestamps and compares independently defined side/bottom hypotheses. It
derives endpoint values from two final observed pre-command frames, checks their
height spread against the 0.25pt goal, then reports residuals without trimming.
Tiny residuals are shared-pipeline arithmetic consistency, not independent
optical accuracy. The native sibling confirmed detached presentation ancestry
and partial-state conversion issues; both cohorts are invalid for full
trajectory acceptance. Their direction/OS bottom differences are provisional
recorder-output hypotheses. iOS 27's ten completion-frame anomalies remain in
every metric. Require coherent presentation-tree recollection before accepting
those trajectories or implementing inferred OS-specific bottom motion.
`native_spacing_ios27_coherent.json` also retains ten unavailable detent samples
and ten remaining anomalies, and exits unresolved. The second-geometry
`native_spacing_vphone_ios26_6_2.json` records ten actual virtual-device trials
at 430×932. It has no flagged spacing anomaly but still requires independent
sampling calibration. No actual Flutter pair has been accepted yet.

Trace alignment, geometry comparison, motion fitting, parity tolerances, plots,
and machine-readable PASS/FAIL reports live here.
