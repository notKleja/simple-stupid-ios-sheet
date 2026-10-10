# Upstream foundation

Vendored `stupid_simple_sheet` 1.0.0-dev.4, the newest published prerelease
verified on 2026-10-06. The pub.dev stable `latest` field is 0.9.1+1; that
field does not include the newest prerelease. Source is preserved from the
published archive, including MIT license, tests, and examples.

- Repository: https://github.com/whynotmake-it/rivership
- Package: https://pub.dev/packages/stupid_simple_sheet/versions/1.0.0-dev.4
- Archive: https://pub.dev/api/archives/stupid_simple_sheet-1.0.0-dev.4.tar.gz
- SHA256: `13ebc967c9a9fd2f60c675f9dafe4e0cfedb1d1dfd50256d408903a01bfb87ad`
- Published: 2026-09-15T17:49:06.731196Z
- Upstream HEAD observed during audit: `f1818c117ea7974c804d66b54083227ca1d26879`
- Copyright: 2025 Tim Lehmann for whynotmake.it

Local changes and the opaque API layer are tracked in Git. The local engine
fork is `ios_sheet_engine` version `1.0.0-dev.4+fork.1`, located at
`packages/ios_sheet_engine` with barrel `package:ios_sheet_engine/ios_sheet_engine.dart`.
The archive identity and provenance above continue to describe upstream.
The legacy glass route remains in the fork to preserve upstream compatibility;
the new API and candidate application never instantiate it. Retaining upstream source is not a
claim that its geometry or physics matches iOS 26 or 27.
