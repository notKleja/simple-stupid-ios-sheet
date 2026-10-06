# Graph Report - parity-harness  (2026-10-06)

## Corpus Check
- 38 files · ~15,507 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 4 file(s) not represented in the graph (top: (none) 4)

## Summary
- 311 nodes · 485 edges · 25 communities (16 shown, 9 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.95)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `3ad0c1cb`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- compare.py
- trace
- properties
- test_compare.py
- trace.schema.json
- properties
- properties
- properties
- evidence.schema.json
- ios26.json
- ios27.json
- Master state
- Measurement + parity validation handoff
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
1. `trace()` - 29 edges
2. `ComparisonTests` - 27 edges
3. `require()` - 19 edges
4. `compare()` - 12 edges
5. `finite()` - 11 edges
6. `config()` - 11 edges
7. `TraceError` - 10 edges
8. `validate()` - 8 edges
9. `read_jsonl()` - 8 edges
10. `rms()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `run()` --uses--> `TraceError`  [INFERRED]
  analysis/regression.py → analysis/compare.py
- `main()` --uses--> `TraceError`  [INFERRED]
  analysis/spacing.py → analysis/compare.py
- `fixture()` --calls--> `trace()`  [EXTRACTED]
  analysis/tests/test_spacing.py → analysis/tests/test_compare.py
- `fit()` --calls--> `TraceError`  [EXTRACTED]
  analysis/fit.py → analysis/compare.py
- `pairs()` --calls--> `finite()`  [EXTRACTED]
  analysis/fit.py → analysis/compare.py

## Import Cycles
- None detected.

## Communities (25 total, 9 thin omitted)

### Community 0 - "compare.py"
Cohesion: 0.12
Nodes (41): compare(), finite(), indexed_events(), interpolate(), main(), metric_report(), Compare observed JSONL trace pairs. Standard library only; never invent samples., First sample of final continuously in-band suffix; no unseen dwell inferred. (+33 more)

### Community 1 - "trace"
Cohesion: 0.15
Nodes (5): ComparisonTests, config(), trace(), matrix(), RegressionTests

### Community 2 - "properties"
Cohesion: 0.07
Nodes (28): const, items, type, type, required, type, type, properties (+20 more)

### Community 3 - "test_compare.py"
Cohesion: 0.20
Nodes (13): Synthetic mathematics fixtures only; no fixture is a native measurement., Synthetic model fits; these do not establish an Apple spring., InspectTests, Test ingestion QC against labeled synthetic samples., Coverage tests contain only synthetic trace pairs; no runtime acceptance claims., fixture(), Synthetic scaled-container geometry, never Apple measurements., SpacingTests (+5 more)

### Community 4 - "trace.schema.json"
Cohesion: 0.11
Nodes (17): allOf, $defs, size, exclusiveMinimum, type, $id, height, width (+9 more)

### Community 5 - "properties"
Cohesion: 0.11
Nodes (18): type, properties, run_id, schema_version, seq, t_ns, type, unavailable (+10 more)

### Community 6 - "properties"
Cohesion: 0.12
Nodes (17): enum, minimum, type, type, properties, type, minimum, type (+9 more)

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

### Community 12 - "Measurement + parity validation handoff"
Cohesion: 0.40
Nodes (4): Measurement + parity validation handoff, Recorded native relationships (provisional, limited domain), Tooling and verification, Uncertainty, blockers, next decision

### Community 14 - "Simple Stupid iOS Sheet"
Cohesion: 0.33
Nodes (5): Evidence policy, Repository layout, Simple Stupid iOS Sheet, Status, Upstream

### Community 17 - "evidence.json"
Cohesion: 0.50
Nodes (3): entries, $schema, schema_version

### Community 23 - "Trace analysis"
Cohesion: 0.29
Nodes (6): Comparison formulas, Current native relationship evidence, Fitting diagnostics, Matrix and holdouts, Tolerances and repeat noise, Trace analysis

## Knowledge Gaps
- **118 isolated node(s):** `$schema`, `title`, `type`, `required`, `const` (+113 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 147 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `trace()` connect `trace` to `test_compare.py`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **What connects `$schema`, `title`, `type` to the rest of the system?**
  _118 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `compare.py` be split into smaller, more focused modules?**
  _Cohesion score 0.11840888066604996 - nodes in this community are weakly interconnected._
- **Should `properties` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._
- **Should `trace.schema.json` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Should `properties` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Should `properties` be split into smaller, more focused modules?**
  _Cohesion score 0.11764705882352941 - nodes in this community are weakly interconnected._