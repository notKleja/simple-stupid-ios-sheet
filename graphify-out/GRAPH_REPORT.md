# Graph Report - parity-harness  (2026-10-06)

## Corpus Check
- 38 files · ~22,320 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 4 file(s) not represented in the graph (top: (none) 4)

## Summary
- 359 nodes · 610 edges · 26 communities (17 shown, 9 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.95)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a52b2db9`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- compare.py
- ComparisonTests
- properties
- test_regression.py
- trace.schema.json
- properties
- RegressionTests
- properties
- evidence.schema.json
- ios26.json
- ios27.json
- Master state
- Measurement + parity handoff
- properties
- Simple Stupid iOS Sheet
- FitTests
- evidence.json
- Third-party notices
- Trace analysis
- artifacts/README.md
- docs/README.md
- flutter_reference/README.md
- CONTRACT.md
- measurement/README.md
- native_reference/README.md
- DIFF_26_27.md

## God Nodes (most connected - your core abstractions)
1. `ComparisonTests` - 37 edges
2. `trace()` - 33 edges
3. `require()` - 22 edges
4. `RegressionTests` - 16 edges
5. `finite()` - 14 edges
6. `compare()` - 13 edges
7. `full_trace()` - 13 edges
8. `full_config()` - 12 edges
9. `TraceError` - 11 edges
10. `config()` - 11 edges

## Surprising Connections (you probably didn't know these)
- `run()` --uses--> `TraceError`  [INFERRED]
  analysis/regression.py → analysis/compare.py
- `main()` --uses--> `TraceError`  [INFERRED]
  analysis/spacing.py → analysis/compare.py
- `fixture()` --calls--> `trace()`  [EXTRACTED]
  analysis/tests/test_spacing.py → analysis/tests/test_compare.py
- `gate_records()` --calls--> `full_trace()`  [EXTRACTED]
  analysis/tests/test_regression.py → analysis/tests/test_compare.py
- `fit()` --calls--> `TraceError`  [EXTRACTED]
  analysis/fit.py → analysis/compare.py

## Import Cycles
- None detected.

## Communities (26 total, 9 thin omitted)

### Community 0 - "compare.py"
Cohesion: 0.11
Nodes (49): compare(), transitions(), finite(), indexed_events(), interpolate(), main(), metric_report(), First sample of final continuously in-band suffix; no unseen dwell inferred. (+41 more)

### Community 1 - "ComparisonTests"
Cohesion: 0.14
Nodes (6): ComparisonTests, config(), full_config(), full_trace(), Synthetic provenance-marker simulation for eligibility-gate tests only., trace()

### Community 2 - "properties"
Cohesion: 0.07
Nodes (28): const, items, type, type, required, type, type, properties (+20 more)

### Community 3 - "test_regression.py"
Cohesion: 0.17
Nodes (15): Synthetic mathematics fixtures only; no fixture is a native measurement., Synthetic model fits; these do not establish an Apple spring., InspectTests, Test ingestion QC against labeled synthetic samples., Coverage tests contain only synthetic trace pairs; no runtime acceptance claims., fixture(), Synthetic scaled-container geometry, never Apple measurements., SpacingTests (+7 more)

### Community 4 - "trace.schema.json"
Cohesion: 0.08
Nodes (27): allOf, $defs, nullableRect, size, exclusiveMinimum, minimum, type, $id (+19 more)

### Community 5 - "properties"
Cohesion: 0.11
Nodes (18): type, properties, run_id, schema_version, seq, t_ns, type, unavailable (+10 more)

### Community 6 - "RegressionTests"
Cohesion: 0.20
Nodes (5): complete_matrix(), gate_records(), matrix(), Explicitly synthetic records with simulated runtime markers to exercise gate…, RegressionTests

### Community 7 - "properties"
Cohesion: 0.05
Nodes (48): items, type, enum, items, type, items, type, minLength (+40 more)

### Community 8 - "evidence.schema.json"
Cohesion: 0.20
Nodes (9): type, properties, entries, schema_version, required, $schema, const, title (+1 more)

### Community 9 - "ios26.json"
Cohesion: 0.25
Nodes (7): major_version, measurements, platform, $schema, schema_version, status, unresolved

### Community 10 - "ios27.json"
Cohesion: 0.25
Nodes (7): major_version, measurements, platform, $schema, schema_version, status, unresolved

### Community 11 - "Master state"
Cohesion: 0.25
Nodes (7): Accepted facts, Active pull requests, Architecture, Current parity score, Master state, Next three highest-value tasks, Unresolved questions

### Community 12 - "Measurement + parity handoff"
Cohesion: 0.33
Nodes (5): Blockers / next decision, Implemented / verified, Measurement + parity handoff, PR #19 fix round 1, Recorded relationships — provisional, not accepted trajectories

### Community 13 - "properties"
Cohesion: 0.12
Nodes (17): enum, minimum, type, type, properties, type, minimum, type (+9 more)

### Community 14 - "Simple Stupid iOS Sheet"
Cohesion: 0.33
Nodes (5): Evidence policy, Repository layout, Simple Stupid iOS Sheet, Status, Upstream

### Community 17 - "evidence.json"
Cohesion: 0.50
Nodes (3): entries, $schema, schema_version

### Community 23 - "Trace analysis"
Cohesion: 0.25
Nodes (7): Comparison formulas, Current native relationship evidence, Fitting diagnostics, Matrix and holdouts, Record validation, Tolerances and repeat noise, Trace analysis

## Knowledge Gaps
- **126 isolated node(s):** `$schema`, `title`, `type`, `required`, `const` (+121 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 159 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `trace()` connect `ComparisonTests` to `test_regression.py`, `RegressionTests`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Why does `ComparisonTests` connect `ComparisonTests` to `test_regression.py`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **What connects `$schema`, `title`, `type` to the rest of the system?**
  _126 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `compare.py` be split into smaller, more focused modules?**
  _Cohesion score 0.10831586303284417 - nodes in this community are weakly interconnected._
- **Should `ComparisonTests` be split into smaller, more focused modules?**
  _Cohesion score 0.13704994192799072 - nodes in this community are weakly interconnected._
- **Should `properties` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._
- **Should `trace.schema.json` be split into smaller, more focused modules?**
  _Cohesion score 0.07671957671957672 - nodes in this community are weakly interconnected._