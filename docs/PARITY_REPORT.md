# Native iOS sheet parity report

Status: **working foundation; final acceptance not achieved**.

This report separates what was observed from what remains unmeasured. Build,
launch, synthetic analyzer tests, resting geometry, and full native parity are
distinct evidence layers.

## Delivered and verified

- GitHub repository, linked Project, eight tracks, and 18 behavior-focused
  issues.
- Opaque UIKit/SwiftUI native reference harness with simulator and vPhone
  collection, runtime metadata, layer/animation sampling, hashes, integrity
  gates, and no Liquid Glass dependency.
- Ninety accepted native traces across nine profiles, ten independent trials
  each. The integrity gate requires cardinality, uniqueness, homogeneous
  metadata/configuration, ordered boundaries, finite stable rest windows,
  explained nulls, and valid terminal state.
- Vendored `stupid_simple_sheet` 1.0.0-dev.4 with upstream MIT attribution and
  115 upstream tests retained.
- Opaque Flutter route/controller with point-based detents, per-OS profiles,
  undimmed pointer passthrough, scroll policy seams, dismissal-lock separation,
  pluggable geometry/physics, recorder, candidate app, and playground.
- Analyzer with real-event alignment, union-grid trajectory errors, static and
  dynamic metrics, schema/provenance gates, conservative noise handling,
  conditional fitting, 248 matrix cells, 1,480 mandatory checks, and eight
  adversarial holdout families.
- Complete-tree verification: 148 Flutter tests, 54 analyzer tests, 15 native
  evidence tests, clean Flutter analyzers, native simulator/device builds, and
  native manifest integrity all pass.

## Exact matches established

For the exact 402×874 portrait page-sheet configuration on iOS 26.4.1 and iOS
27.0, native and candidate repeated resting geometry is:

| State | x | y | width | visible height | bottom inset |
|---|---:|---:|---:|---:|---:|
| medium | 8 | 415.0265339966832 | 386 | 450.9734660033168 | 8 |
| large | 0 | 62 | 402 | 812 | 0 |

Native resting spread is zero across ten trials per accepted cohort. The
candidate cohorts repeat the same values. This establishes scoped resting
geometry, not transition or gesture parity.

The actual iOS 26 v2 pair also matches all five comparison metadata objects,
the 13-key effective configuration, all seven canonical event payloads, and
selected/target/gesture transition sequences. Raw platform identifiers remain
available as provenance while comparison uses canonical IDs.

## Measured platform differences

- System medium resolves to `0.56 × maximumDetentValue` in every accepted
  phone, iPad page, and measured form cohort; it is not simply half height.
- Floating page geometry scales the whole surface. For the matched phone,
  floating scale is `(screenWidth - 16) / screenWidth` and the visible medium
  height uses physical-pixel rounding before scaling.
- A regular-width iPad form with preferred content 320×320 resolves maximum
  330 pt and medium 184.8 pt on iOS 26, versus maximum 1158 pt and medium
  648.48 pt on iOS 27.
- iOS 27 leading form placement produces x=25 pt versus automatic centered
  x=257 pt in the measured 834×1210 environment.

See `spec/ios26.json`, `spec/ios27.json`, `spec/DIFF_26_27.md`, and
`spec/evidence.json` for scoped values, provenance, and limitations.

## Known failures and unresolved coverage

The actual v2 pair is structurally compatible but the analyzer verdict is
**FAIL**:

- Event-timing errors range from 61.89375 ms to 302.348458 ms where the limit
  is one 60 Hz frame (16.666667 ms).
- First-visible timing error is 127.002833 ms.
- Candidate tail coverage is incomplete; the reference tail is not trimmed.
- The comparison is a diagnostic subset. Full geometry, radius, barrier,
  presenter transform, scroll ownership, hit testing, and input fields remain
  absent from this pair.

Native dynamic evidence also retains 50 explicit non-resting geometry gaps and
a one-frame iOS 27 teardown observation. No samples were hidden to obtain a
pass. Compositor analysis did not observe a matching footer jump in 1,434
frames, but its unsynchronized cadence cannot exclude an unsampled frame.

Still unmeasured or incomplete:

- finger-to-sheet transfer, overdrag, velocity thresholds, snap policy, and
  interruption energy continuity;
- true native nonmodal background touches and scroll handoff;
- scalar radius and full corner contour;
- barrier alpha and presenter transformation;
- keyboard timing, dynamic resizing, stacking, orientation/compact-height,
  accessibility settings, and frame-pacing regressions;
- iOS 27 vPhone behavior, because no usable iOS 27 guest is available;
- adversarial holdout replay after profiles are frozen.

## Acceptance classification

- **Exact:** scoped resting medium/large geometry and v2 structural contract.
- **Within tolerance:** no additional dynamic category accepted yet.
- **Known platform limitation:** iOS 27 vPhone unavailable in current inventory.
- **Unresolved discrepancy:** timing, reference-tail coverage, native dynamic
  gaps, and the unmeasured interaction/adaptivity families above.

The repository is ready for the next measurement/implementation cycle, but it
must not be described as full native iOS sheet parity until the matrix and
holdouts pass on fresh iOS 26 and iOS 27 runs.
