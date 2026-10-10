# Fork provenance

The public wrapper `simple_stupid_ios_sheet` uses iOS 26 as its only supported
native reference. The default `IosSheetProfile.ios26` remains an explicitly
unmeasured fallback. Source lineage does not certify native geometry, timing,
interaction, or complete accepted parity.

| Layer | Identity and origin | Local purpose / difference | License |
| --- | --- | --- | --- |
| Upstream archive | `stupid_simple_sheet` `1.0.0-dev.4`, Rivership by Tim Lehmann for whynotmake.it | Immutable source identity for the original transition foundation, tests, and examples | Upstream MIT, Copyright (c) 2025 Tim Lehmann for whynotmake.it |
| Local engine | `ios_sheet_engine` `1.0.0-dev.4+fork.1`, `flutter_reference/packages/ios_sheet_engine`, barrel `package:ios_sheet_engine/ios_sheet_engine.dart` | Renamed local fork; physics, resistance, handoff, motion, and recorder seams; legacy routes retained | Separate upstream MIT retained in engine `LICENSE` |
| Public wrapper | `simple_stupid_ios_sheet` `0.1.0-dev.2`, `flutter_reference/packages/ios_sheet` | Opaque semantic detents, controller, strict iOS 26 resolver, helper, research contracts | Root MIT copied byte-for-byte into wrapper, Copyright (c) 2026 notKleja |
| Candidate and public example | `flutter_reference/candidate` and wrapper `example` | Research playground versus minimal public helper app; neither promotes native evidence | Repository MIT |

## Archive and corroboration

The imported archive is
[`stupid_simple_sheet-1.0.0-dev.4.tar.gz`](https://pub.dev/api/archives/stupid_simple_sheet-1.0.0-dev.4.tar.gz),
SHA-256 `13ebc967c9a9fd2f60c675f9dafe4e0cfedb1d1dfd50256d408903a01bfb87ad`,
published `2026-09-15T17:49:06.731196Z`. These are recorded import facts, not a
claim that the package is currently the newest upstream version. The import
commit is `051809f4f6df104d1fcbbda386416ddd9a1ee7eb`
(`chore(flutter): vendor sheet engine dev.4`). Engine rename commit:
`f87e1ce` (`refactor: rename engine to ios_sheet_engine`).

The observed upstream HEAD recorded during the inception audit was
`f1818c117ea7974c804d66b54083227ca1d26879`. A read-only `git ls-remote --tags`
check on 2026-10-11 resolved `stupid_simple_sheet-v1.0.0-dev.4` to
`33a7a913e01ecc0c300f917e0d91fc6d91ab1f0f`. The tag and observed HEAD are
corroborating repository evidence, not substitutes for the archive hash or a
claim that HEAD and the release tag are identical. Upstream location:
[whynotmake-it/rivership](https://github.com/whynotmake-it/rivership/tree/main/packages/stupid_simple_sheet).
The preserved [UPSTREAM.md](../flutter_reference/UPSTREAM.md) and
[third-party notices](../THIRD_PARTY_NOTICES.md) carry the original attribution.

## Fork seams and sync risks

The engine adds point-based resistance hooks, release-velocity transfer,
boundary-crossing resistance, continuous scroll handoff, read-only
instrumentation, and motion request/simulation seams consumed by the wrapper.
Its standalone legacy example retains its own configuration. The wrapper and
candidate never instantiate the retained legacy glass route; their dependency
closure has no Liquid Glass rendering package.

Install the full checkout via the wrapper path. Published `stupid_simple_sheet`
does not supply fork-only seams and cannot replace `ios_sheet_engine` through a
package alias. Engine and wrapper identity changes require synchronized imports,
workspace manifests, external consumer checks, and reviewed API documentation.

When syncing upstream, compare against the recorded archive, retain upstream
tests/goldens and MIT attribution, and review changes to controller retargeting,
velocity, snap, gesture handoff, disposal, and rendering. Passing upstream tests
does not guarantee wrapper compatibility or native parity. Re-run host checks
and separately qualify any native evidence; preserve unsupported-version and
geometry rejection instead of widening claims. No hosted publication has been
performed; relative engine dependencies currently limit hosted publishability.
