#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$script_dir/.."

# Preserve the engine's upstream formatting and four existing drift files.
# Analysis and host tests still cover the engine and all exempt files.
format_paths=()
while IFS= read -r -d '' path; do
  case "$path" in
    packages/ios_sheet/lib/src/content_adaptation.dart|\
    packages/ios_sheet/test/content_adaptation_test.dart|\
    candidate/lib/synchronized_demo.dart|\
    candidate/test/synchronized_demo_test.dart)
      continue
      ;;
    *.dart)
      format_paths+=("$path")
      ;;
  esac
done < <(git ls-files -z -- \
  packages/ios_sheet/lib packages/ios_sheet/test \
  packages/ios_sheet/tool packages/ios_sheet/example \
  candidate/lib candidate/test)
test "${#format_paths[@]}" -gt 0
dart format --output=none --set-exit-if-changed "${format_paths[@]}"
