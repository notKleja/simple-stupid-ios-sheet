# Phase 2 timing diagnostic

Status: **FAIL; no native parity claimed.** Twenty fresh canonical v2 candidate
trials (ten per OS) are structurally compatible with actual native references:
scenario, OS/build, device, environment and all 13 configuration keys match.
The opaque route and unsupported opening-interruption rejection are unchanged.

## Corrections and boundary audit

Candidate route/content preparation now precedes the real `present.requested`.
Replay commands use independent absolute deadlines from that request, not
successive waits that accumulate command-processing overhead. Actual receipts
are recorded; no nominal timestamp, renamed completion, warmup or copied native
event is emitted. Two regressions were observed failing before implementation
and now pass, including an overdue deadline that retains its real receipt time.

The old diagnostic's “tail” message also covers missing **leading** coverage.
Fresh candidate tails cover all 20 native tails; first-frame coverage fails 8/10
on 26 and 7/10 on 27 against the corrected cohorts. No frame was fabricated to
fill the interval before layout.

Native timer audit independently found approximately 75/150/225ms accumulated
command lateness. Native source `741175b9` corrects this using zero-leeway timers
and a shared real boundary. Its new source-hashed 10+10 cohorts are compared
below; pre-correction reports and failed attempts remain archived. Fsync was
tested and falsified as the cause (native audit max 1.32ms). No motion tuning
compensates for delayed native command delivery.

## Corrected native boundary results

Unchanged merged comparator/profile; one 60Hz frame=16.667ms timing limit.
Each entry below is median / maximum absolute event error, in milliseconds.

| Boundary | iOS26.4.1 | iOS27.0 |
|---|---:|---:|
| first visible |18.101 /413.623|21.767 /462.710|
| presentation complete |401.417 /437.358|409.647 /444.127|
| select large |1.944 /10.853|1.872 /6.598|
| select medium |1.499 /4.748|0.992 /6.281|
| dismiss requested |1.692 /6.316|1.453 /5.039|
| dismiss complete |413.232 /426.237|414.417 /436.911|

All 60 programmatic command boundaries pass. Candidate real command medians
are 1502.155/3001.715/4501.818ms on 26 and 1502.072/3001.669/4501.748ms on 27,
confirming the lack of accumulated delay. Whole trace PASS:0/10 on each OS.
First-visible passes 5/10 on 26 and 3/10 on 27; neither completion passes.

Real event-bounded phase diagnostics retain the same gates, unknown frames and
original timestamps. Medium→large sheet-y RMS 22.091–30.022pt on 26 and
17.173–28.923pt on 27; maxima 66.295–94.076pt and 53.246–90.246pt respectively.
Large→medium on 26: RMS 22.092–28.170pt, max 65.963–85.698pt. On 27 only one
trial is numerically available (RMS 25.885pt, max 77.450pt); nine retain native
geometry gaps and FAIL. Dismissal RMS 38.406–63.831pt on 26 and 42.851–59.921pt
on 27. Opening is measurable in only 2/10 and 3/10 respectively due leading
coverage failures; no cropped opening can establish whole-phase acceptance.
These are diagnostic numeric errors, not calibrated optical trajectories.

## Evidence and unresolved decisions

- Candidate immutable manifests: `artifacts/flutter/timing_v2_ios{26,27}_attempt1/manifest.json`.
  Ten distinct run/trial IDs each, training split, raw/compressed hashes,
  source diff/Dart hashes and executable hash; debug Simulator builds, no warmup.
- Corrected native manifests: `artifacts/native/timing/ios{26,27}_strict_anchored/manifest.json`.
  Exact sibling-published bytes at `53c0592`, build source `741175b9`; source
  is pinned in manifest, while original header source marker remains unresolved.
  Resting/replay timing acceptance only, not motion promotion; native code and
  accepted main measurement manifest are not modified by this branch.
- Native 27 unchanged-source baselines: `artifacts/native/ios27_0_v2_timing_reference{,_attempt2}/manifest.json`.
  Attempt1 fails resting sampling QC and stays audited; attempt2 passes ten-trial
  resting QC only. Neither is promoted as motion evidence. Original26 v2 cohort
  remains unchanged.
- Final reports: `artifacts/analysis/timing_v2/native{26,27}_strict_anchored.json`;
  baselines: `native{26,27}_pre_correction.json` in the same directory.
  They bind source hashes and retain whole-trace FAIL plus four explicit phases.
- Opening cold-start cost, leading sample coverage, native teardown geometry,
  missing presenter-scale observation and fallback Motor completion remain
  unresolved. Existing CASpring animation-object values are
  `observed_not_promoted`; they were not promoted or fitted to hide these errors.
  A calibrated accepted opening/detent/dismissal trajectory is required before
  changing motion. Debug/JIT Simulator cold-start maxima are retained rather
  than hidden with warmup; they do not establish physical-device startup parity.

Verification:150 Flutter tests pass (115 upstream+32 API+3 candidate), 54 analyzer
tests pass, 15 native evidence tests pass. API/candidate analyzers are clean;
vendored upstream retains its two existing informational lint findings.
Both arm64 Simulator builds succeed. Existing native manifest integrity PASS:
90 traces, 9 profiles, 50 explicit geometry gaps; full geometry parity unresolved.
