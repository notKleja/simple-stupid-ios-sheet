# Graph Report - native-reference  (2026-10-06)

## Corpus Check
- 78 files · ~127,295 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 178 file(s) not represented in the graph (top: .gz 170, (none) 5, .log 2)

## Summary
- 566 nodes · 988 edges · 49 communities (35 shown, 14 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `4e3f90c7`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- compare.py
- ComparisonTests
- properties
- json
- trace.schema.json
- properties
- RegressionTests
- properties
- evidence.schema.json
- ios26.json
- ios27.json
- Master state
- Measurement + parity handoff
- EvidenceTests
- Simple Stupid iOS Sheet
- FitTests
- Harness
- evidence.json
- NativeScenario
- evidence_contract.py
- Native iOS Sheet Parity Design
- .record
- Third-party notices
- Trace analysis
- artifacts/README.md
- docs/README.md
- flutter_reference/README.md
- CONTRACT.md
- measurement/README.md
- .scene
- App.swift
- type
- native_reference/README.md
- DIFF_26_27.md
- Review Focus
- CalibrationView
- .layerInfo
- items
- SwiftUIReference
- Native reference milestone
- ProbeWindow
- id
- samples
- stddev
- trials
- ios
- unit
- build.sh
- package_device.sh

## God Nodes (most connected - your core abstractions)
1. `ComparisonTests` - 37 edges
2. `trace()` - 33 edges
3. `Harness` - 26 edges
4. `require()` - 22 edges
5. `EvidenceTests` - 21 edges
6. `RegressionTests` - 16 edges
7. `finite()` - 14 edges
8. `compare()` - 13 edges
9. `full_trace()` - 13 edges
10. `full_config()` - 12 edges

## Surprising Connections (you probably didn't know these)
- `run()` --uses--> `TraceError`  [INFERRED]
  analysis/regression.py → analysis/compare.py
- `main()` --uses--> `TraceError`  [INFERRED]
  analysis/spacing.py → analysis/compare.py
- `fixture()` --calls--> `trace()`  [EXTRACTED]
  analysis/tests/test_spacing.py → analysis/tests/test_compare.py
- `ProbeWindow` --references--> `Trace`  [EXTRACTED]
  native_reference/NativeSheetHarness/App.swift → native_reference/NativeSheetHarness/Trace.swift
- `Harness` --references--> `Trace`  [EXTRACTED]
  native_reference/NativeSheetHarness/App.swift → native_reference/NativeSheetHarness/Trace.swift

## Import Cycles
- None detected.

## Communities (49 total, 14 thin omitted)

### Community 0 - "compare.py"
Cohesion: 0.11
Nodes (48): compare(), transitions(), finite(), indexed_events(), interpolate(), main(), metric_report(), First sample of final continuously in-band suffix; no unseen dwell inferred. (+40 more)

### Community 1 - "ComparisonTests"
Cohesion: 0.15
Nodes (4): ComparisonTests, config(), trace(), InspectTests

### Community 2 - "properties"
Cohesion: 0.04
Nodes (45): enum, minimum, type, type, const, items, type, type (+37 more)

### Community 3 - "json"
Cohesion: 0.07
Nodes (37): full_config(), full_trace(), Synthetic mathematics fixtures only; no fixture is a native measurement., Synthetic provenance-marker simulation for eligibility-gate tests only., Synthetic model fits; these do not establish an Apple spring., Test ingestion QC against labeled synthetic samples., gate_records(), Coverage tests contain only synthetic trace pairs; no runtime acceptance claims. (+29 more)

### Community 4 - "trace.schema.json"
Cohesion: 0.08
Nodes (27): allOf, $defs, nullableRect, size, exclusiveMinimum, minimum, type, $id (+19 more)

### Community 5 - "properties"
Cohesion: 0.11
Nodes (18): type, properties, run_id, schema_version, seq, t_ns, type, unavailable (+10 more)

### Community 6 - "RegressionTests"
Cohesion: 0.24
Nodes (3): complete_matrix(), matrix(), RegressionTests

### Community 7 - "properties"
Cohesion: 0.12
Nodes (16): enum, type, properties, type, type, confidence, formula, os_build (+8 more)

### Community 8 - "evidence.schema.json"
Cohesion: 0.25
Nodes (7): properties, schema_version, required, $schema, const, title, type

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

### Community 14 - "Simple Stupid iOS Sheet"
Cohesion: 0.33
Nodes (5): Evidence policy, Repository layout, Simple Stupid iOS Sheet, Status, Upstream

### Community 16 - "Harness"
Cohesion: 0.14
Nodes (12): CADisplayLink, CGFloat, Harness, .probe, Bool, URL, canonicalDetentID(), Notification (+4 more)

### Community 17 - "evidence.json"
Cohesion: 0.50
Nodes (3): entries, $schema, schema_version

### Community 18 - "NativeScenario"
Cohesion: 0.14
Nodes (12): Error, Foundation, Int, Legacy interpretation, Native recorder contract v2, Profile acceptance, NativeScenario, ScenarioError (+4 more)

### Community 19 - "evidence_contract.py"
Cohesion: 0.26
Nodes (14): adapt_legacy(), canonical_id(), finite(), identity(), Native acceptance controls; legacy adaptation never rewrites hashed sources., read(), require(), validate_cohort() (+6 more)

### Community 20 - "Native iOS Sheet Parity Design"
Cohesion: 0.12
Nodes (15): Analyzer and regression system, Delivery sequence, Evidence and profiles, Failure handling, Flutter package and candidate harness, Flutter semantic model, Intent, Measurement contracts (+7 more)

### Community 21 - ".record"
Cohesion: 0.26
Nodes (9): FileHandle, Int64, Any, Bool, Double, String, URL, Trace (+1 more)

### Community 23 - "Trace analysis"
Cohesion: 0.25
Nodes (7): Comparison formulas, Current native relationship evidence, Fitting diagnostics, Matrix and holdouts, Record validation, Tolerances and repeat noise, Trace analysis

### Community 29 - ".scene"
Cohesion: 0.16
Nodes (12): App, SceneDelegate, Set, UIApplication, UIApplicationDelegate, UIOpenURLContext, UIResponder, UIScene (+4 more)

### Community 30 - "App.swift"
Cohesion: 0.26
Nodes (10): Darwin, deviceModel(), insets(), osBuild(), rect(), Double, String, QuartzCore (+2 more)

### Community 31 - "type"
Cohesion: 0.18
Nodes (11): items, type, type, items, type, hypotheses, limitations, run_ids (+3 more)

### Community 34 - "Review Focus"
Cohesion: 0.20
Nodes (9): Global Constraints, Native iOS Sheet Parity Integration Plan, Review Focus, Task 1: Integrate the measurement contract, Task 2: Integrate the analyzer and regression matrix, Task 3: Integrate the native reference harness, Task 4: Integrate the Flutter engine and public API, Task 5: Reconcile contracts and complete measured profiles (+1 more)

### Community 35 - "CalibrationView"
Cohesion: 0.25
Nodes (4): CGRect, CalibrationView, NSCoder, UIView

### Community 36 - ".layerInfo"
Cohesion: 0.48
Nodes (5): CALayer, coherentLayerSamples(), sampledWindowRect(), Any, ObjectIdentifier

### Community 37 - "items"
Cohesion: 0.29
Nodes (7): items, type, items, type, required, artifacts, entries

### Community 38 - "SwiftUIReference"
Cohesion: 0.29
Nodes (6): SwiftUIReference, .body, PresentationDetent, SwiftUI, UIKit, View

### Community 39 - "Native reference milestone"
Cohesion: 0.29
Nodes (6): Changed files, branch and decisions, Conclusions and measured constants, Confidence and uncertainty, Failed hypotheses worth knowing, Native reference milestone, Review fix round1

### Community 40 - "ProbeWindow"
Cohesion: 0.40
Nodes (4): CGPoint, ProbeWindow, TimeInterval, UIEvent

### Community 41 - "id"
Cohesion: 0.67
Nodes (3): minLength, type, id

### Community 42 - "samples"
Cohesion: 0.67
Nodes (3): samples, minimum, type

### Community 43 - "stddev"
Cohesion: 0.67
Nodes (3): stddev, minimum, type

### Community 44 - "trials"
Cohesion: 0.67
Nodes (3): trials, minimum, type

## Knowledge Gaps
- **159 isolated node(s):** `$schema`, `title`, `type`, `required`, `const` (+154 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 239 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `trace()` connect `ComparisonTests` to `json`, `RegressionTests`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Why does `EvidenceTests` connect `EvidenceTests` to `json`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Why does `Harness` connect `Harness` to `CalibrationView`, `.layerInfo`, `ProbeWindow`, `.record`, `.scene`, `App.swift`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **What connects `$schema`, `title`, `type` to the rest of the system?**
  _159 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `compare.py` be split into smaller, more focused modules?**
  _Cohesion score 0.11175616835994194 - nodes in this community are weakly interconnected._
- **Should `ComparisonTests` be split into smaller, more focused modules?**
  _Cohesion score 0.14761904761904762 - nodes in this community are weakly interconnected._
- **Should `properties` be split into smaller, more focused modules?**
  _Cohesion score 0.044444444444444446 - nodes in this community are weakly interconnected._