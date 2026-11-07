#!/usr/bin/env bash
# Runtime-owned tools are declared separately by each host.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/core.sh"
load_runtime
manifest="$HOME/.config/dotfiles/expected.json"
read_list() { python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))[sys.argv[2]]))' "$manifest" "$1"; }
installer() (
  url="$1"; interpreter="$2"; shift 2
  temporary="$(mktemp)"
  trap 'rm -f "$temporary"' EXIT
  curl --proto '=https' --tlsv1.2 -fsSL "$url" -o "$temporary"
  "$interpreter" "$temporary" "$@"
)
mkdir -p "$HOME/.local/bin" "$HOME/.npm-global"
packages=()
# Install only missing or changed direct versions. Extra local npm packages remain user-owned.
packages_to_install="$(python3 - "$manifest" "$HOME" <<'PYTHON'
import json, pathlib, sys
for name, version in json.load(open(sys.argv[1]))['npmPackages'].items():
    path = pathlib.Path(sys.argv[2]) / '.npm-global/lib/node_modules' / name / 'package.json'
    if not path.is_file() or json.loads(path.read_text())['version'] != version:
        print(f'{name}@{version}')
PYTHON
)"
while IFS= read -r package; do [[ -z "$package" ]] || packages+=("$package"); done <<< "$packages_to_install"
[[ ${#packages[@]} == 0 ]] || npm install --global --prefix "$HOME/.npm-global" "${packages[@]}" </dev/null
vendors="$(read_list vendorTools)"
while IFS= read -r tool; do
  [[ -n "$tool" ]] || continue
  # Never treat a stale Linuxbrew or npm binary as a native CLI installation.
  case "$tool" in
    claude) binary="$HOME/.local/bin/claude" ;;
    codex) binary="$HOME/.local/bin/codex" ;;
    grok) binary="$HOME/.local/bin/grok" ;;
    t3) binary="$HOME/.local/bin/t3" ;;
    opencode) binary="$HOME/.opencode/bin/opencode" ;;
    apm) binary="$HOME/.local/bin/apm" ;;
  esac
  if [[ -x "$binary" ]]; then
    info "$tool already installed at $binary"
    continue
  fi
  case "$tool" in
    claude) installer https://claude.ai/install.sh bash latest ;;
    codex) CODEX_NON_INTERACTIVE=1 installer https://chatgpt.com/codex/install.sh sh ;;
    grok) SHELL=/bin/sh installer https://x.ai/cli/install.sh bash ;;
    t3) installer https://t3.codes/install.sh sh ;;
    apm) uv tool install apm-cli ;;
    opencode) source "$DOTFILES_DIR/scripts/lib/opencode.sh"; install_opencode_v2 ;;
  esac
  [[ -x "$binary" ]] || die "$tool did not install $binary"
done <<< "$vendors"
