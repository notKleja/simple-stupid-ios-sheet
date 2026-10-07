# Runtime pairing contract v1

Canonical v2 recorders retain the schema1 JSONL envelope. Runtime orchestration
does not rewrite source records, substitute events, loosen limits or infer absent
observations. `analysis/runtime_batch.py` consumes immutable cohort manifests
and produces source-hashed pair/phase reports through the merged `compare.py`.

A cohort manifest has `schema_version:1`, `cohort_id`, `implementation`
(`native`/`flutter`), `split` (`diagnostic`/`training`/`holdout`), and `artifacts`.
Each artifact declares `path` (relative to manifest or absolute), `sha256`,
`run_id`, positive `trial`, positive `attempt`, and `status`
(`complete`/`partial`/`failed`/`unsupported`). `source_path` is an accepted path
alias for producer manifests. Paths never serve as evidence of identity; bytes,
header, sequence, v2 configuration and terminal record must validate.

All 13 effective configuration keys and canonical detent IDs are required.
Metadata/configuration must match exactly for a pair, including the same trial
counter. Cohort identity excludes only the trial counter. Run IDs/hashes cannot
pad independent trials or cross frozen split boundaries. A successful terminal
record is `dismiss.completed` with `terminal:true`; `run.error` invalidates the
run even when marked complete in a manifest. Missing terminal, truncated JSON,
missing files or incomplete observations are retained as partial/unresolved.
Only an approved `batch.completed` provenance event may follow success.

Attempts are ordered by integer attempt, never directory order or measured
error. Choose the first structurally complete attempt for each trial. Incomplete
or invalid predecessors remain in the audit. A complete attempt that fails
comparison is never replaced by a numerically better retry. Duplicate attempt,
run or artifact identities invalidate the affected roster.

A frozen batch plan pins the matrix, full analyzer profile and recipes by hash,
declares expected trial IDs/cells/checks, and assigns cohort-manifest hashes to
cells. Training is tuning evidence; holdouts are frozen separately. Diagnostic
pairs never count toward matrix acceptance. Frozen split files are immutable;
new captures produce a new plan revision rather than silently editing a prior
assignment. The split registry checks hashes, run IDs and trial ownership across
all splits, even when the invocation runs one split only.

Every phase uses its matrix-owned observed window and a matching real alignment
boundary. The strict analyzer's complete report is retained. PASS additionally
requires full-profile eligibility. Missing/unimplemented evidence stays
UNRESOLVED; concrete numerical/timing/semantic discrepancies are FAIL. Analyzer
FAIL is never changed to PASS. A complete case needs the intersection of passing
trial IDs across every declared check; absent cells remain visible.

Commands:

```
python3 analysis/runtime_batch.py freeze plan.json --output-directory measurement/runtime/frozen
python3 analysis/runtime_batch.py run frozen-index.json --output artifacts/runtime/report.json
```

`import-cohort` requires an explicit producer adapter (`flutter-timing-v1`,
`native-timing-v1`, `native-reference-v1`, or `native-interaction-pilot-v1`),
source root, role/split/cohort ID and content-addressed artifact directory.
It copies source bytes and the producer manifest without rewriting them,
checks compressed/raw hashes, preserves opaque attempt IDs and producer
quality outcomes, and never promotes a diagnostic pilot. New frozen plans pin
`holdout_definitions` as well as matrix/profile/recipe hashes. Example:

```
python3 analysis/runtime_batch.py import-cohort producer.json --adapter flutter-timing-v1 --source-root /source/repository --implementation flutter --split training --cohort-id candidate-v2 --output measurement/runtime/cohorts/candidate.json --artifact-directory artifacts/runtime/imports
```

The initial baseline-v1 index predates the holdout-definition pin and remains
an explicitly labeled historical diagnostic index. It assigns no holdout capture
and provides no acceptance credit. New batches require the full freeze contract.

Tests use explicitly synthetic fixtures, including simulated runtime provenance
markers needed to exercise gates. They do not establish native parity. The
current real v2 pair is an immutable diagnostic baseline with no acceptance claim.

## Explicit mapping plans v2

Opt in with `schema_version:2` on the plan/index (the JSONL envelope stays1).
The plan must pin a `scenario_map` path and SHA256; its bytes are checked both
before freezing and before any run, including single-split runs. Entries declare
exact `matrix`, `native`, `flutter`, and positive integer `revision` values.
Matrix/source aliases are unique within each revision. Null counterparts are
unimplemented and cannot form a pair. `scenario-map-v2.json` lists the current
programmatic registration plus four native-only interaction registrations; the
downward case remains outside the live matrix until the later matrix task.

Each frozen assignment, recipe, and observed trace session declares a positive
integer `scenario_revision` matching the chosen entry. This is independent of
`conditions.recipe_revision`. The recipe's `conditions.recipe_id` must equal its
actual `id`. Both sessions must match the frozen recipe's condition identity:
recipe_id, recipe_revision, parameters, input_source, accessibility. Accessibility
must additionally match the observed environment.system_settings. Complete
conditions validate against the additive v2 schema; parameters never enter the
exact13-key semantic configuration. A v1 index cannot silently ignore v2 markers.

An explicit match permits only a scenario_id-only in-memory comparison view.
It changes no source bytes, metrics, states, timestamps or events. Original IDs
and the entry/revision remain visible in pair reports. The view is revalidated
against canonical scenario event gates before the unchanged comparator runs.
Configured equality alone provides no outcome or numerical acceptance credit.
Applicability declarations are not exemptions in this stage.

Historical v1 indexes retain their old counts and comparisons. Only the exact
known profile/matrix path+hash pairs use the byte-identical v1 snapshots; other
hash mismatches still reject. Raw traces, frozen assignments and saved reports
are never rewritten. A new orchestrator run truthfully records its new source
hash rather than pretending to be the historical executable.
