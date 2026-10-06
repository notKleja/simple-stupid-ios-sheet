# Simple Stupid iOS Sheet

An evidence-driven Flutter implementation of native Apple sheet behavior for
iOS 26 and iOS 27, built from the `stupid_simple_sheet` transition engine.

This project targets native geometry, detent semantics, interaction,
interruptible motion, scroll handoff, presenter transformation, keyboard
behavior, stacking, modal and nonmodal behavior, and adaptive layout. The
shipping surface is deliberately opaque and does **not** implement or depend on
Liquid Glass.

## Repository layout

- `native_reference/` — deterministic UIKit and SwiftUI ground-truth harness.
- `flutter_reference/` — Flutter package, parity harness, and playground.
- `measurement/` — trace schema, recorders, gesture recipes, and tooling.
- `analysis/` — trace comparison, curve fitting, and reports.
- `spec/` — measured iOS profiles, evidence, test matrix, and master state.
- `docs/` — architecture, experiment protocols, and public API documentation.
- `artifacts/` — representative trace and A/B evidence manifests.

## Evidence policy

Package defaults are not treated as Apple behavior. Every shipping constant
must point to a repeated native measurement, documented Apple semantic,
derived formula, or an explicitly labeled fallback. Unmeasured values remain
unresolved rather than being presented as native parity.

## Upstream

The implementation is derived from
[`stupid_simple_sheet`](https://pub.dev/packages/stupid_simple_sheet), version
`1.0.0-dev.4` at project inception. The upstream package is maintained in
[`whynotmake-it/rivership`](https://github.com/whynotmake-it/rivership/tree/main/packages/stupid_simple_sheet)
and is licensed under the MIT License. See `THIRD_PARTY_NOTICES.md`.

## Status

Research and implementation are tracked in the linked
[GitHub Project](https://github.com/users/notKleja/projects/1). Current accepted
facts and open questions live in `spec/MASTER_STATE.md`.

