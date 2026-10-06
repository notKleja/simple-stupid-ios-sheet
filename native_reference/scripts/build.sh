#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
platform="${1:-iphonesimulator}"
case "$platform" in
  iphonesimulator) target=arm64-apple-ios26.0-simulator ;;
  iphoneos) target=arm64-apple-ios26.0 ;;
  *) exit 2 ;;
esac
app="build/native/$platform/NativeSheetHarness.app"
mkdir -p "$app" build/native/module-cache
cp native_reference/NativeSheetHarness/Info.plist "$app/Info.plist"
sdk="$(xcrun --sdk "$platform" --show-sdk-path)"
xcrun swiftc -sdk "$sdk" -target "$target" -module-cache-path build/native/module-cache \
  -parse-as-library native_reference/NativeSheetHarness/*.swift \
  -framework UIKit -framework QuartzCore -framework SwiftUI -o "$app/NativeSheetHarness"
codesign --force --sign - "$app"
printf '%s\n' "$PWD/$app"
