# Native reference harness

An opaque UIKit app records real native sheet geometry, delivered touch events,
native custom-detent resolver context, raw system layers and runtime Core
Animation objects. No glass route or material implementation is included.
SwiftUIReference.swift provides a separate opaque SwiftUI comparison surface;
its runtime parity has not yet been measured.

Build with `bash native_reference/scripts/build.sh iphonesimulator` or
`bash native_reference/scripts/package_device.sh`. Xcode27 SDK is required for
the guarded `preferredPlacement` experiment. The build is ad-hoc signed;
distribution/ordinary device installation is outside this research build.

The measured recipe `native.medium_large.programmatic` presents system medium,
requests large after1.5s, medium after3s, and dismissal after4.5s. The native
detent list includes a320pt custom resolver probe, medium and large, in that
order. Every trial has its own run ID. These exact configurations matter when
consuming measurements; this is not a universal system profile.

`python3 native_reference/scripts/collect_simulator.py <UDID> --output
artifacts/native/<cohort>` collects ten complete trials and records the
simulator runtime build from simctl, rather than the host kernel build.
The simulator must already be booted. `NATIVE_SWIFTUI=1` selects the standalone
SwiftUI surface. `NATIVE_SCENARIO` and `NATIVE_TRIALS` select UIKit experiments.
Explicit NativeScenario definitions expose custom initial selection, nonmodal
medium, dismissal disabled, scroll/content-first, keyboard, form/page sizing,
compact edge attachment and iOS27 leading/trailing placement. Unknown IDs fail;
there is no substring/default fallthrough. Only the explicitly
archived measured recipes carry evidence. Drag/scroll/keyboard scenarios stay
open for external input rather than executing the timed recipe.

Existing vPhone research workflow:

1. Package the device build.
2. `python3 native_reference/scripts/vphone_run.py <machine> --install`.
3. `python3 native_reference/scripts/collect_vphone.py <machine> --output
   artifacts/native/<cohort>` after the batch completes.

The vPhone helper uses the existing machine socket, installs through vphoned
(not installd), verifies actual foreground ownership, then posts the native
Darwin start notification. This notification recipe supports the default ten
trials. Standard installd rejected the ad-hoc test binary; vphoned research
installation does not establish distributable signing. No bootstrap, guest OS,
host security setting or other app is modified.

`summarize_native.py` derives resting medians in the last0.4s before each next
request boundary and emits per-artifact SHA256, per-trial spread and source
quality. `record_simulator.py` captures compositor video alongside fresh
traces. `analyze_footer_video.py` examines the known red footer; video has its
own clock and variable frame cadence, so it cannot independently establish
display-frame-perfect alignment.

The primary trace format is schema1 JSONL, compressed only for archival. The
latest recorder samples one coherent window presentation tree and preserves
unsupported/missing frames as explicit null/unavailable records. Earlier
mixed-tree conversion cohorts are retained for audit and resting geometry;
they must not be used to establish uninterrupted dynamics. Scalar sheet radius,
effective barrier alpha, native scroll ownership and actual background hit
testing remain unresolved. `present.first_visible` is the first observed
positive visible height; callback completion is not a settling detector.
