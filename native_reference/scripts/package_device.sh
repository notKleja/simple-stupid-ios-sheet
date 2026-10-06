#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
bash native_reference/scripts/build.sh iphoneos
mkdir -p build/native/device-payload/Payload
cp -R build/native/iphoneos/NativeSheetHarness.app build/native/device-payload/Payload/
cd build/native/device-payload
zip -qr ../NativeSheetHarness.ipa Payload
