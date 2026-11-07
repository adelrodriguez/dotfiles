#!/usr/bin/env bash
# Assess each domain using the caller's PATH. Never source the runtime loader here.
set -euo pipefail
repo="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home_only=()
services=true
for option in "$@"; do
  case "$option" in
    --home-only) home_only=(--home-only); services=false ;;
    --no-services) services=false ;;
    -h|--help) printf '%s\n' 'Usage: scripts/doctor.sh [--home-only] [--no-services]'; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$option" >&2; exit 2 ;;
  esac
done
status=0
python3 "$repo/tools/check.py" ${home_only[@]+"${home_only[@]}"} || status=1
python3 "$repo/home/check.py" || status=1
python3 "$repo/agents/check.py" || status=1
if "$services"; then python3 "$repo/services/check.py" || status=1; fi
exit "$status"
