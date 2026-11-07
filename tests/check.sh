#!/usr/bin/env bash
# Fixture tests only. installed-tools.sh separately checks a provisioned host.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for test in roles link sync packages packages-macos upstream-packages github-release agents-env agents fish-limits grok-completions runtime doctor; do
  printf '\nRunning %s\n' "$test"
  bash "$repo/tests/$test.sh"
done
