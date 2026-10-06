# Flutter runtime evidence

- `ios26_4_1_candidate`: ten completed iOS26.4.1/build23E254a simulator trials.
- `ios27_0_candidate`: ten completed iOS27.0/build24A434 simulator trials.
- `ios27_0_candidate_metadata_invalid`: ten initial trials with the host Mac's
  kernel build misreported as the simulated OS build. Excluded from pairing;
  preserved unmodified to make the instrumentation defect auditable.

All use the canonical `native.medium_large.programmatic` scenario and opaque
content. Metadata, commands, post-layout transformed geometry and categorical
state are JSONL v1. SHA256 hashes, frame counts and resting medians are in
`flutter_reference/measurements.json`.

These are actual candidate runtime traces, not widget-test fixtures. Their
resting geometry uses native training measurements. Dynamic geometry contains
explicit provisional hypotheses; motion, radius and barrier still use labeled
fallbacks. No complete native parity or holdout acceptance is claimed.

Time comes from a Dart monotonic Stopwatch sampled after a Flutter frame,
with microsecond precision encoded as nanoseconds. This is not a GPU present
timestamp. Pointer velocity, scroll ownership and actual background-hit-test
values remain null with reasons until the corresponding probes are attached.
