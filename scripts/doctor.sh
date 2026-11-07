#!/usr/bin/env bash
# Observe the active runtime without modifying packages, files, or services.
set -euo pipefail
repo="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "$repo/checks/installed.py" "$@"
