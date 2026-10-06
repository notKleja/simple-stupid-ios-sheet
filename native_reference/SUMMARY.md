# Native reference milestone

## Conclusions and measured constants

Ten completed trials per accepted cohort. Units are logical points. Evidence
and SHA256 references are in `native_reference/measurements.json`; raw JSONL.gz,
runtime inventories and compositor video are in `artifacts/native/`.

For the measured portrait page recipe `[fixed320, medium, large]`, system
medium resolves to `0.56 * maximumDetentValue`, not half the maximum. Large
resolves to the maximum. At medium the whole page sheet is uniformly scaled
to `(screenWidth-16)/screenWidth`, with8pt side and bottom spacing. Resting
visible medium height equals
`round((resolvedMedium + bottomSafeArea) * displayScale) / displayScale * scale`.
For the402pt phone: `round((435.68+34)*3)/3*(386/402)=450.9734660033168`.
At large it is full width, bottom spacing0 and visible height
`resolvedLarge + bottomSafeArea`. This is a measured configuration, not an
OS-wide rule for every sheet type.

| Runtime/device | Screen | Native max/medium | Medium visible height | Large top/height |
|---|---|---|---|---|
|26.4.1 simulator iPhone17Pro|402×874|778 /435.68|450.9734660033168|62 /812|
|27.0 simulator iPhone18Pro|402×874|778 /435.68|450.9734660033168|62 /812|
|26.6.2 vPhone iPhone99,11|430×932|839 /469.84|485.246511627907|59 /873|
|26.4.1 simulator iPad11|834×1210|1143 /640.08|652.242206235012|42 /1168|
|27.0 simulator iPad11|834×1210|1158 /648.48|655.6750599520384|32 /1178|

Matched phone geometry is identical at rest on26 and27. The iPad page cohorts
have differing captured safe areas; their absolute differences must not be
called an isolated change to detent semantics.

Regular-width form sheets with preferred content320×320 differ materially.
With valid ascending detents,26.4.1 resolves maximum330 and medium184.8;
width320, centered x257, medium y580/height185, large y435/height330,
bottom spacing445. The matched27 automatic form resolves maximum1158 and
medium648.48, keeps width320 and bottom spacing20, and allows much taller
content. iOS27 leading placement puts this form at x25. Exact profiles and
confidence are in the evidence JSON. SDK27 adds `preferredPlacement`; there
is no usable27 vPhone in the existing machine inventory.

Runtime CASpringAnimation objects are archived, including one observed detent
family with mass1, stiffness333.3333332805039, damping36.51483716411749,
initial velocity0 and duration0.5058237871186482. These are animation-object
parameters, not a verified universal finger-release transfer function.

## Confidence and uncertainty

High confidence in the scoped repeated resting values and native resolver
outputs; resting per-trial standard deviation is0 in the reported windows.
Full trajectory acceptance is unresolved. Detached presentation-layer
conversion produces coordinate artifacts. Coherent window-tree sampling
retains unavailable frames and still reports a one-frame y0 transient near
iOS27 detent animation teardown. Recorded compositor pixels showed no red
footer above820pt in1434 captured frames, but video cadence and clocks cannot
exclude an unsampled display frame. Do not implement that transient as native
movement or discard it to get a passing comparison.

Scalar visible radius, full clipping contour, effective barrier alpha,
gesture physics/overdrag/snap policy, actual background hit testing, scroll
handoff, keyboard/stacking/interruptibility and accessibility behavior remain
unmeasured. SwiftUI reference code builds but has no accepted runtime cohort.
System settings are captured in the newest form traces; older cohorts lack
that metadata. No full native parity or matrix completion is claimed.

## Review fix round1

Recorder v2 emits canonical medium/large/custom IDs with raw UIKit values kept
separately, validates explicit scenario definitions, and records the complete
effective UIKit configuration. All null metric/state fields have reasons.
Serialization failure writes a terminal error without a sequence hole and
invalidates further recording. CONTRACT_V2.md defines the version boundary.

Both evidence tools enforce exactly ten files, unique run/trial IDs,
homogeneous identity/configuration/environment, ordered complete boundaries,
and fully observed/stable400ms resting windows. The prior27 automatic form
cohort failed a41ms resting-window gap; it remains archived and is excluded
from accepted profiles. Fresh v2 phone/form cohorts pass these gates.
Integrity:90 accepted traces, nine profiles,50 explicit non-resting geometry
gaps. Full trajectory/native parity remains unresolved.

Archived v1 cohorts require native-legacy-v1 explicitly; original bytes/hashes
are unchanged, null explanations identify legacy instrumentation gaps, and
missing effective configuration flags are not inferred. Fresh v2 traces are
required for strict pairing with the complete current configuration.

## Failed hypotheses worth knowing

- Half-maximum medium is falsified in all accepted cohorts.
- Side spacing alone is insufficient: native floating page height scales too.
- One universal page formula does not cover form sizing or placement.
- `present()`/dismissal completion callbacks do not establish physical settling.
- Direct presentation-layer conversion across trees is not reliable at teardown.
- The initial26 form pilot used misordered detents; only the sorted cohort is
  accepted. The pilot remains archived for audit.
- Standard installd rejects the ad-hoc binary. vphoned research installation
  succeeds but does not prove distribution signing. Guest URL launch timed out;
  verified foreground launch plus a Darwin notification reliably starts trials.

## Changed files, branch and decisions

`native_reference/NativeSheetHarness/`: UIKit recorder, opaque rulers/footer,
scene lifecycle and SwiftUI companion. `native_reference/scripts/`: build,
device packaging, simulator/vPhone collection, evidence summarization and
compositor capture/pixel analysis. `artifacts/native/`: real cohorts and video.
`graphify-out/.gitignore` excludes regenerable local relationship output.

Branch `research/native-reference`; early commits `2fef38c`, `94f0093`.
No Flutter engine or parity analyzer implementation was edited.

Next decision: accept scoped resting profiles only; keep full dynamics failing
until the teardown observation is synchronized to compositor pixels. Then
prioritize deterministic vPhone gesture/nonmodal/scroll recipes, followed by
keyboard and stacking. iOS27 vPhone evidence requires a usable27 guest runtime;
no machine or firmware/security configuration was replaced to obtain it.
