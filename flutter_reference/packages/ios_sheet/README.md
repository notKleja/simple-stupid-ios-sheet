# Simple Stupid iOS Sheet

This package uses iOS 26 as its only native-reference scope.

Its default `IosSheetProfile.ios26` is an explicitly unmeasured fallback, not
a claim of complete observed or accepted native parity.

`simple_stupid_ios_sheet` is an opaque Flutter sheet API over the local
`ios_sheet_engine` fork. It provides semantic detents, a caller-owned controller,
and `showIos26Sheet`. It has no Liquid Glass dependency. Version
`0.1.0-dev.2` remains unpublished (`publish_to: none`).

## Install from a checkout

Use the verified Flutter 3.44.6 release, which bundles Dart 3.12.2, for the
checkout commands below. The complete workspace requires Dart 3.12.2 or later
within Dart 3 because the candidate declares `sdk: ^3.12.2`. Clone the complete
repository so the sibling engine path is retained:

```sh
git clone https://github.com/notKleja/simple-stupid-ios-sheet.git
cd simple-stupid-ios-sheet/flutter_reference
flutter pub get
```

In your app's `pubspec.yaml`, use the wrapper path from that checkout:

```yaml
dependencies:
  flutter:
    sdk: flutter
  simple_stupid_ios_sheet:
    path: /absolute/path/simple-stupid-ios-sheet/flutter_reference/packages/ios_sheet
```

Run `flutter pub get` in your app. The wrapper resolves its engine through
`../ios_sheet_engine`; copying the wrapper alone is insufficient. There is no
hosted-package installation for this fork yet.

The wrapper's own manifest declares Dart `>=3.12.0 <4.0.0` and Flutter
`>=3.44.0`. Those lower bounds have not been verified; they are separate from
the complete checkout's Dart 3.12.2 requirement. Package checks and external
path consumption were verified with Flutter 3.44.6 / Dart 3.12.2.

## Show a sheet

```dart
import 'package:flutter/cupertino.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

Future<void> openSheet(BuildContext context) async {
  await showIos26Sheet<void>(
    context: context,
    detents: const [IosSheetDetent.medium, IosSheetDetent.large],
    initialDetentIdentifier: 'medium',
    builder: (_) => const Center(child: Text('Sheet content')),
  );
}
```

The helper uses the nearest navigator; set `useRootNavigator: true` to present
on the root navigator. `routeSettings` supplies route name and arguments. The
returned `Future<T?>` carries the typed pop result. Route-construction validation
is synchronous, including an empty detent list or unknown initial/undimmed ID;
it can throw before a future is returned. Geometry-dependent validation happens
when the route resolves its environment.

## Control and ownership

Create an `IosSheetController` in the presenting widget's state, pass it to the
helper, and dispose it when that owner is disposed. The helper and route do not
dispose a supplied controller. Attach it to one sheet at a time; reuse only
after that route has detached following dismissal. `isAttached` and
`isPresented` describe different stages. Wait for presentation before changing
detents for fixed-surface profiles.

Use `selectDetent('large')` to request a semantic detent and `dismiss(result)` to
close explicitly. `selectedDetentIdentifier` is the accepted selection;
`restingDetentIdentifier` is null while moving or dragging. A covered sheet
cannot be selected or dismissed through its controller. The
[example](example/lib/main.dart) demonstrates ownership and medium/large controls.

## Construct a route directly

For an explicit profile or advanced research seams, construct the route:

```dart
Navigator.of(context).push<void>(
  StupidSimpleIosSheetRoute<void>(
    profile: IosSheetProfile.ios26,
    detents: const [IosSheetDetent.medium, IosSheetDetent.large],
    initialDetentIdentifier: 'medium',
    child: const Center(child: Text('Sheet content')),
  ),
);
```

The helper intentionally omits `trajectoryModel` and
`onUnderlyingHitObserved`. Those two seams require direct route construction.
Use `IosSheetProfile.forReferenceVersion(26)` for strict reference resolution;
other major versions throw `UnsupportedError`. Deprecated iOS 27 APIs remain
for source compatibility and are unsupported research fallbacks.

## Support and evidence

| Surface | Implementation status | Native evidence status |
| --- | --- | --- |
| iOS 26 helper and strict resolver | Supported public entry points | Default profile is unmeasured |
| Medium, large, fixed, fraction, custom detents | Implemented with ID/height validation | Default sizing is fallback behavior |
| Controller, callbacks, explicit dismissal | Implemented and covered by host tests | Full UIKit lifecycle parity remains unverified |
| Drag, scroll handoff, snap, overdrag | Engine-backed behavior and profile seams | Exact native arbitration and physics remain open |
| Undimmed threshold, opaque styling | Implemented barrier and pointer behavior | Native visual/timing parity is not accepted |
| Keyboard resize/overlay | Implemented policy choice | Native keyboard synchronization remains open |
| `observedIos26Page402x874Profile()` | Qualified research profile only | Partial resting evidence; provisional transfer hypotheses |
| Presenter transform, stacking, adaptive sizing, accessibility | Incomplete native behavior coverage | No full parity claim |
| iOS 27 | Deprecated compatibility APIs only | Unsupported reference scope |

The qualified profile requires 402x874 points at 3x, safe area 62/34, portrait,
keyboard hidden, and the observed page scenario with fixed320/medium/large.
It rejects other geometry. Resting samples do not accept dynamic contour,
translation, timing, gestures, or interruption parity. Native recorder coordinate
defects leave width/bottom transfer hypotheses provisional. Host tests,
Simulator runs, and physical/native comparisons prove different layers; passing
package tests does not promote native evidence.

## Run the example and checks

From `flutter_reference`:

```sh
flutter pub get --no-example
flutter test --no-pub packages/ios_sheet/example/test
cd packages/ios_sheet/example
flutter create --platforms=ios --no-pub .
flutter run -t lib/main.dart -d <device-id>
```

The checked-in example is a minimal Flutter app source. The `flutter create`
step generates its local iOS platform scaffolding before the first run. The
example includes no trace recorder, native metadata channel,
profile selector, or Liquid Glass dependency.

See [troubleshooting](doc/troubleshooting.md), [contributing](CONTRIBUTING.md),
and the [changelog](CHANGELOG.md). Repository evidence and source lineage are
recorded in [fork provenance](../../../docs/FORK_PROVENANCE.md).

## License and upstream

The wrapper [LICENSE](LICENSE) is the repository MIT license, copied exactly,
Copyright (c) 2026 notKleja. The engine retains its separate upstream MIT
license, Copyright (c) 2025 Tim Lehmann for whynotmake.it. Its source foundation
is [`stupid_simple_sheet` 1.0.0-dev.4](https://pub.dev/packages/stupid_simple_sheet/versions/1.0.0-dev.4)
from [Rivership](https://github.com/whynotmake-it/rivership). The local renamed
engine includes fork-only seams; installing the published upstream package
does not supply those seams.
