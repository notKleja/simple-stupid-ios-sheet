# Runtime parity batch — phase 2

Branch `test/runtime-parity-batch` starts at merged main `e16fbdd`.
Scope: immutable manifest discovery, canonical v2 integrity, deterministic
independent-trial pairing, retry/partial-run audit, frozen training/holdout
isolation, unchanged strict analyzer and per-phase/full-case aggregation.
No app implementation edits. Contract: `measurement/RUNTIME_CONTRACT.md`.

Baseline available: one real iOS26 canonical v2 pair, metadata/event vocabulary
compatible but timing/tail coverage FAIL. It is diagnostic only. Native and
Flutter siblings are producing fresh manifest-hashed timing/interaction cohorts.
All absent or unimplemented matrix cells remain unresolved; no passing pairs
or measurements are manufactured. Runtime counts and verification pending.
