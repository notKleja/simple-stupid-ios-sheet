# Replay timing diagnosis

Confidence: high for command scheduling contamination; not an accepted native motion law.

The retained iOS26 audit (`artifacts/native/timing/coalescing_diagnostic/manifest.json`) compares two independent clock deltas at actual callback entry. Nominal 1500/3000/4500ms callbacks arrived at CACurrentMediaTime deltas 1572.9368/3151.5780/4724.9533ms and DispatchTime deltas 1572.9375/3151.5787/4724.9553ms. The clocks agree; the delay is not a timestamp-conversion artifact. The maximum observed event synchronize call was 1.3203ms, not ~75ms. This falsifies synchronous durable flushing as the cause of the repeated ~75ms steps in this diagnostic. Synchronous writes can still contribute to frame pacing, which this experiment does not settle.

The harness now retains strict DispatchSourceTimer objects with zero requested leeway and anchors the three programmatic deadlines to one presentation-command boundary. It preserves observed timestamps, durable terminal/error behavior, and a diagnostic-only coalesced mode. Strict timers are best-effort; main-thread workload can still delay actual invocation.

Ten corrected trials on each OS are sealed in `artifacts/native/timing/ios26_strict_anchored/manifest.json` and `ios27_strict_anchored/manifest.json`. Source is verified Git commit `741175b9dabaf68a5083cfc6ab426a531cd27397`; the original raw header's unresolved source marker remains unchanged and is explicitly disclosed in each manifest. These are replay-boundary/resting-evidence cohorts, not newly accepted transition dynamics.

Actual command medians in milliseconds relative to present.requested:

| Runtime | Large request | Medium request | Dismiss request |
| --- | ---: | ---: | ---: |
| iOS26.4.1 simulator | 1500.186896 | 3000.314146 | 4500.175022 |
| iOS27.0 simulator | 1500.157750 | 3000.256480 | 4500.213729 |

Maximum positive offsets from those nominal boundaries were 0.8321/1.3286/0.3386ms on26 and 0.3373/3.1905/2.7928ms on27. No compensating delay, fabricated early completion, or sampled private spring was promoted into Flutter/native truth.
