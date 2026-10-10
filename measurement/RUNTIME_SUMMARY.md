# Runtime parity batch — phase 2

Branch `test/runtime-parity-batch` starts at merged main `e16fbdd`.
Scope: immutable manifest discovery, canonical v2 integrity, deterministic
independent-trial pairing, retry/partial-run audit, frozen training/holdout
isolation, unchanged strict analyzer and per-phase/full-case aggregation.
No app implementation edits. Contract: `measurement/RUNTIME_CONTRACT.md`.

Implementation: `analysis/runtime_batch.py` imports explicit producer manifests,
copies source bytes into content-addressed storage, verifies compressed/raw
hashes, enforces canonical v2/configuration/terminal integrity, selects first
structurally complete attempts, seals splits and runs unchanged `compare.py`.
Earlier partial/failed attempts remain audited; a complete numerical failure
cannot be replaced by a better retry. Matrix actions/geometry roles are enforced.
Holdout definitions and split files are hash-pinned even on training-only runs.

## Actual runtime results

- Historical diagnostic baseline: 1 pair, 6 phase FAIL; no acceptance credit.
- Corrected native timing + candidate timing: 20 compatible independent pairs
  (10 per OS), 120 phase checks: **0 PASS / 120 FAIL / 0 UNRESOLVED**.
- Matrix coverage: **0 PASS / 2 FAIL / 246 UNRESOLVED**, 248 cells and 1480
  required checks. All uncollected/unimplemented cases remain visible.
- Command receipts: 60/60 within one native frame; maximum10.852792ms on26,
  6.597833ms on27. Metadata/event-vocabulary mismatch issues: zero.
- Full-profile presentation-window leading failures: 5/10 on26, 7/10 on27.
  Global callback timing, trajectory/coverage and unavailable observations still
  fail. Per-phase alignment changes the timing comparison's reference boundary;
  full reports preserve those choices rather than mixing aggregate counts.
- Native nonmodal pilot: 10 exact imported artifacts, explicitly unsupported
  for acceptance (uncommitted diagnostic source, no matched candidate). Its
  activate/block/activate observations remain producer-scoped evidence only.
- vPhone delivery failure: producer reports zero observed touch/control action
  in a bounded prefix, no terminal completion; absence over the unexported tail
  cannot be asserted. It supplies no passing interaction evidence.

Artifacts: `artifacts/runtime/baseline-v2-report.json`, `timing-v2-report.json`,
content-addressed `imports/`; manifests/plans/sealed splits under
`measurement/runtime/`. Producer manifests and raw trace bytes are preserved.
Native build741175b9 is pinned by producer metadata; unresolved raw-header source
markers are never rewritten. Candidate provenance pins executable/source hashes.

## Verification / next decision

**70/70 measurement tests pass**, including16 new runtime gate regressions.
Whitespace checks pass; analyzer diff from merged main is empty; source graph
refreshed AST-only. Tests prove gate behavior, not native physics or display.
Fixtures use explicit synthetic gate simulations and prove software behavior
only. No app implementations or merged analyzer gates were edited.
Limitations: full-profile null/applicability policy and canonical13-key parameter
contract prevent some currently unobservable checks from acceptance; this layer
does not invent observations to bypass them. Most interactions/holdouts and a
second device/orientation reference are still absent. Next: consume sealed
interaction cohorts with matched candidates and approved observable contracts.
