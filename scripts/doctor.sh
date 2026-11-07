#!/usr/bin/env bash
# Inspect the recorded profile and live deployment without changing either.
set -euo pipefail
observed_path="$PATH"
observed_codex_home="${CODEX_HOME:-}"
source "$(dirname "${BASH_SOURCE[0]}")/lib/core.sh"
exec python3 "$DOTFILES_DIR/scripts/lib/doctor.py" "$observed_path" "$observed_codex_home" "$RUNTIME_PATH"
