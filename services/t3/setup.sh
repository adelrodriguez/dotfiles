#!/usr/bin/env bash
set -euo pipefail

base="${T3CODE_HOME:-$HOME/.t3}"
if [[ -f "$base/runtime/service-state.json" ]]; then
  version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["activeVersion"])' "$base/runtime/service-state.json")"
  t3="$base/runtime/versions/$version/t3"
else
  t3="${T3_BIN:-$(command -v t3 || true)}"
fi
if [[ ! -x "$t3" ]]; then
  echo 'Install T3 Code first, or restore ~/.t3. Set T3_BIN to the installed t3 executable on a fresh machine.' >&2
  exit 1
fi
"$t3" service install --base-dir "$base"
systemctl --user is-enabled t3code.service
systemctl --user is-active t3code.service
