#!/usr/bin/env bash
set -euo pipefail

mode="${1:-check}"
if [[ "$mode" != check && "$mode" != format ]]; then
  echo 'Usage: scripts/swift-quality.sh [check|format]' >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tool_dir="$(mktemp -d)"
trap 'rm -rf "$tool_dir"' EXIT

download_tool() {
  local name="$1" version="$2" archive="$3" digest="$4" repository="$5"
  curl --fail --location --silent --show-error \
    "https://github.com/$repository/releases/download/$version/$archive" \
    --output "$tool_dir/$archive"
  printf '%s  %s\n' "$digest" "$tool_dir/$archive" | shasum -a 256 --check --status
  unzip -oq "$tool_dir/$archive" -d "$tool_dir/$name"
}

download_tool swiftlint 0.65.1 portable_swiftlint.zip \
  c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0 realm/SwiftLint
download_tool swiftformat 0.64.7 swiftformat.zip \
  e82e224325cbd3403fc7b68caf6c917926dc106de3af875fca4b87e3c4634038 nicklockwood/SwiftFormat

[[ "$("$tool_dir/swiftlint/swiftlint" version)" == 0.65.1 ]]
[[ "$("$tool_dir/swiftformat/swiftformat" --version)" == 0.64.7 ]]
printf 'SwiftLint 0.65.1; SwiftFormat 0.64.7\n'

cd "$repo_root"
sources=(RealTimePriceTracker/RealTimePriceTracker RealTimePriceTracker/RealTimePriceTrackerTests)
if [[ "$mode" == check ]]; then
  "$tool_dir/swiftlint/swiftlint" lint --config .swiftlint.yml --no-cache --strict "${sources[@]}"
  "$tool_dir/swiftformat/swiftformat" "${sources[@]}" --config .swiftformat --cache ignore --lint
else
  "$tool_dir/swiftformat/swiftformat" "${sources[@]}" --config .swiftformat --cache ignore
fi
