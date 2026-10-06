# Native recorder contract v2

The JSONL envelope remains schema1. New session records additionally carry
`native_contract_version: 2`. System detent identifiers are canonical
`medium` and `large`; custom identifiers are retained verbatim. Original UIKit
identifiers remain in `raw_uikit_identifier` research extras. Programmatic
selection changes the selected UIKit property immediately; callback completion
is not renamed to physical settling. Dismissal has no configured detent target,
so target is null with an explicit applicability reason.

Effective `configuration` records trial, sorted detents, surface, grabber,
page sizing, interactive dismissal lock, largest undimmed detent, presentation
style, preferred content size, placement, compact-height edge attachment,
preferred-width policy and scroll-expansion policy. UIKit getters supply these
values after configuration. Scenario IDs resolve through explicit definitions
in NativeScenario.swift; unknown IDs and unavailable placement fail with a
terminal `run.error` rather than selecting a default behavior.

Every null frame metric/state has an `unavailable` reason. Serialization failure
appends a terminal `run.error` at the failed observation's sequence number,
invalidates the run and suppresses subsequent observations. No sequence number
is consumed by an observation that failed to serialize.

## Legacy interpretation

`native-legacy-v1` is an opt-in, versioned in-memory adapter for archived v1
files. It canonicalizes known UIKit IDs, preserves their raw values, and marks
previously unexplained nulls as legacy instrumentation unavailable. It does not
fill numeric observations, infer newly required effective configuration, rewrite
source bytes, or change source hashes. Legacy profiles are limited to their
recorded configuration and resting geometry. Fresh v2 files are required for
strict pairing against complete configuration; unrecorded legacy flags remain
unresolved. A v2 file cannot opt out of the stricter contract via this adapter.

## Profile acceptance

Both summarization and validation share evidence_contract.py. An accepted
profile requires exactly ten actual artifacts, ten distinct run IDs and trial
IDs1..10, identical scenario/OS/device/environment/effective configuration
(excluding trial counter), the complete ordered request/completion sequence,
large then medium detent requests, and all three complete resting windows.
Each400ms window must have observed endpoints and no gap larger than two
declared native frames; required geometry must be finite throughout and stable
within0.25pt. Missing/null samples are never silently removed to compute a
passing resting profile. Manifest identity must match its hashed first source.
Artifact and run reuse across accepted profiles is rejected.

These gates establish integrity and scoped resting coverage, not full native
parity, contour correctness, gesture physics or physical display presentation.
