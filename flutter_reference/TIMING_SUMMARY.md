# Phase 2 timing diagnostic

Status: **FAIL; no native parity claimed.** Twenty fresh canonical v2 candidate
trials (ten per OS) are structurally compatible with actual native references:
scenario, OS/build, device, environment and all13 configuration keys match.
The opaque route and unsupported opening-interruption rejection are unchanged.

## Corrections and boundary audit

Candidate route/content preparation now precedes the real `present.requested`.
Replay commands use independent absolute deadlines from that request, not
successive waits that accumulate command-processing overhead. Actual receipts
are recorded; no nominal timestamp, renamed completion, warmup or copied native
event is emitted. Two regressions were observed failing before implementation
and now pass, including an overdue deadline that retains its real receipt time.

The old diagnostic's “tail” message also covers missing **leading** coverage.
Fresh candidate tails cover all20 native tails; first-frame coverage fails6/10
on26 and9/10 on27. No frame was fabricated to fill the interval before layout.

Native timer audit independently found approximately75/150/225ms accumulated
command lateness. Zero-leeway timer correction is being collected by the native
track; these initial pair reports explicitly retain the pre-correction native
receipts rather than tuning candidate motion to delayed commands. Fsync was
tested and falsified as the cause (native audit max1.32ms).

## Pre-correction strict results

Unchanged merged comparator/profile; one60Hz frame=16.667ms timing limit.
Each entry below is median / maximum absolute event error, in milliseconds.

| Boundary | iOS26.4.1 | iOS27.0 |
|---|---:|---:|
| first visible |22.767 /384.056|23.322 /550.510|
| presentation complete |401.854 /437.252|420.535 /440.035|
| select large |72.486 /78.154|74.824 /77.537|
| select medium |149.671 /155.618|147.445 /150.868|
| dismiss requested |224.589 /227.525|224.720 /230.010|
| dismiss complete |183.688 /204.407|184.055 /211.070|

Whole trace PASS:0/10 on each OS. Real event-bounded phase diagnostics retain
the same gates, unknown frames and original timestamps. Medium→large sheet-y
RMS30.732–40.372pt on26 and30.700–41.724pt on27; maxima159.490–181.945pt
and149.998–186.782pt respectively. Large→medium on26: RMS80.428–91.470pt,
max316.570–343.146pt. On27 it is unavailable in all10 due explicit native
geometry gaps. Dismissal RMS139.970–150.826pt on26 and135.124–152.217pt on27.
These are diagnostic numeric errors, not calibrated optical trajectories.

## Evidence and unresolved decisions

- Candidate immutable manifests: `artifacts/flutter/timing_v2_ios{26,27}_attempt1/manifest.json`.
  Ten distinct run/trial IDs each, training split, raw/compressed hashes,
  source diff/Dart hashes and executable hash; debug Simulator builds, no warmup.
- Native27 unchanged-source baselines: `artifacts/native/ios27_0_v2_timing_reference{,_attempt2}/manifest.json`.
  Attempt1 fails resting sampling QC and stays audited; attempt2 passes ten-trial
  resting QC only. Neither is promoted as motion evidence. Original26 v2 cohort
  remains unchanged.
- Reports: `artifacts/analysis/timing_v2/native{26,27}_pre_correction.json`.
  They bind source hashes and retain whole-trace FAIL plus four explicit phases.
- Opening cold-start cost, leading sample coverage, native teardown geometry,
  missing presenter-scale observation and fallback Motor completion remain
  unresolved. Existing CASpring animation-object values are
  `observed_not_promoted`; they were not promoted or fitted to hide these errors.
  A calibrated accepted opening/detent/dismissal trajectory is required before
  changing motion. Corrected native deadline receipts will be compared separately.

Verification:150 Flutter tests pass (115 upstream+32 API+3 candidate),54 analyzer
tests pass,15 native evidence tests pass. API/candidate analyzers are clean;
vendored upstream retains its two existing informational lint findings.
Both arm64 Simulator builds succeed. Existing native manifest integrity PASS:
90 traces,9 profiles,50 explicit geometry gaps; full geometry parity unresolved.
