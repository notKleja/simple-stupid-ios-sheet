#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || "$1" != /* || ! -f "$1/pubspec.yaml" ]]; then
  echo 'Usage: bash tool/verify_path_consumer.sh <absolute-wrapper-package-path>' >&2
  exit 64
fi

wrapper_path=$(cd "$1" && pwd -P)
consumer_root=$(mktemp -d "${TMPDIR:-/tmp}/ios-sheet-path-consumer.XXXXXX")
cleanup() {
  local status=$?
  if [[ $status -eq 0 ]]; then
    rm -rf -- "$consumer_root"
  else
    echo "Failed consumer retained at: $consumer_root" >&2
  fi
}
trap cleanup EXIT

consumer_path="$consumer_root/consumer"
flutter create --empty --no-pub --platforms=ios \
  --project-name=external_sheet_consumer "$consumer_path"
# YAML single quotes escape embedded apostrophes by doubling them.
yaml_wrapper_path=${wrapper_path//\'/\'\'}
cat > "$consumer_path/pubspec.yaml" <<YAML
name: external_sheet_consumer
publish_to: none
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  simple_stupid_ios_sheet:
    path: '$yaml_wrapper_path'
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
YAML
mkdir -p "$consumer_path/test"
cat > "$consumer_path/test/package_surface_test.dart" <<'DART'
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_stupid_ios_sheet/simple_stupid_ios_sheet.dart';

void main() {
  test('external consumer resolves the package surface', () {
    expect(IosSheetProfile.ios26.majorVersion, 26);
    expect(IosSheetDetent.large.identifier, 'large');
  });
}
DART

echo "External path consumer: $consumer_path"
cd "$consumer_path"
flutter pub get
flutter analyze --fatal-infos --no-pub
flutter test --no-pub
