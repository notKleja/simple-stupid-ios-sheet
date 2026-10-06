# Brother 2 — Flutter engine milestone

Branch: `feat/ios-sheet-engine`. Working candidate, not full native parity.

## Conclusions

- Verified/vendored newest published prerelease `stupid_simple_sheet` 1.0.0-dev.4
  with original MIT copyright, source, tests and examples. Archive SHA in
  `UPSTREAM.md`; early commits 051809f and ba715f4 are already pushed.
- Opaque `StupidSimpleIosSheetRoute` plus named point/fraction/custom detents,
  semantic controller, callbacks, actual undimmed touch passthrough, independent
  interactive dismissal lock, content-scrolls/content-resizes and keyboard
  resize/overlay policy. No glass route instantiated or exported by this API.
- Independent 26/27 profiles. Optional maximum-detent→visible-height conversion,
  uniform scale/inset/shape resolver, custom snap physics and arbitrary
  point-based overdrag/release seams. Generic/custom engine defaults preserved.
- Qualified 402x874@3x/safe62/34 research profile reproduces native medium/large
  resting frames. It rejects other geometry. Transfer models remain explicit
  hypotheses after the native recorder coordinate-coherence issue.

## Runtime proof and tests

- iOS 26.4.1/build23E254a and 27.0/build24A434 simulator arm64 builds and runs.
  Ten completed runtime trials on each; JSONL v1, monotonic order, actual native
  metadata, command/first-visible/completion events, transformed render corners.
- Both runtime cohorts: medium `(x 8,y 415.026534,w 386,h 450.973466,bottom 8)`;
  large `(x 0,y 62,w 402,h 812,bottom 0)`. Rest medians repeat exactly across ten
  trials; matching trained resting data is not holdout/motion acceptance.
- Full workspace regression suite: 140 tests (115 upstream + 24 API + 1 candidate).
  New contract tests were observed red before implementation. API/candidate
  analyzer clean. Raw cohort hashes and rest summaries: `measurements.json`.
- Initial ten 27 trials retained as metadata-invalid/excluded: simulator
  `kern.osversion` returned the host Mac build. Fixed with runtime environment.
- Installed `lipo` rejects multi-arch verification; reproducible arm64-only
  Xcode build succeeds. Candidate minimum deployment target is 26.

## Changed areas

`flutter_reference/packages/stupid_simple_sheet`, `packages/ios_sheet`,
`candidate` (playground/native metadata host), `ARCHITECTURE.md`,
`FALLBACKS.json`, `measurements.json`; `artifacts/flutter` contains 20 corrected
and 10 excluded compressed traces. Local AST graph rebuilt for repository policy.

## Uncertainty / blockers / next decision

No implementation/build blocker remains for this milestone. Native motion,
barrier/radius, gesture/snap laws, keyboard timing, scrolling arbitration,
presenter transform/stacking, interruptibility and accessibility remain
unaccepted. Page/form/content adaptation, source-view/27 placement, dynamic
content retarget and phase-specific motion API remain unfinished; the public
coverage matrix in `ARCHITECTURE.md` does not pretend otherwise.

Master next: integrate this foundation with native and parity branches; consume
fresh coherent native traces before promoting transfer formulas or replacing
fallback springs. Native/Flutter matched runtime comparison and holdout matrix
must determine the next engine/API extensions. Do not mark overall mission
complete from this milestone.
