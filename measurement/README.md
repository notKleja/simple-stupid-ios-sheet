# Measurement

Common JSONL trace schema, native and Flutter recorders, device metadata,
replayable gesture recipes, and collection scripts live here.

- `CONTRACT.md` and `schema/`: recorder, evidence, gesture contracts v1.
- `profiles/`: explicit initial mission targets and diagnostic-only subsets.
- `recipes/programmatic.json`: controlled medium/large programmatic sequence.
- `holdouts.json`: frozen adversarial families; bind actual geometry and hash
  generated recipes before execution.
- `regression_manifest.json`: currently empty, intentionally FAIL/unresolved.
- `SUMMARY.md`: compact workstream handoff, measured relationships and blockers.

The native and Flutter app implementations own their recorder integration;
analysis tooling reads their append-only records without rewriting the evidence.
No trace in the test suite is a native measurement.
