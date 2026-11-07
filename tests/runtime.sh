#!/usr/bin/env bash
# Exercise new shell and service children with an isolated, versioned Node installation.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME/.config/dotfiles" "$HOME/.local/share/fnm/aliases/default/bin" "$HOME/.npm-global/bin" "$HOME/.config/codex" "$HOME/.codex"
printf 'mac\n' > "$HOME/.config/dotfiles/profile"
printf 'compiled instructions\n' > "$HOME/.codex/AGENTS.md"
printf 'private auth\n' > "$HOME/.config/codex/auth.json"
cat > "$HOME/.local/share/fnm/aliases/default/bin/node" <<'SH'
#!/bin/sh
echo fixture-node
SH
chmod +x "$HOME/.local/share/fnm/aliases/default/bin/node"
cp -R "$repo/scripts" "$repo/roles" "$repo/profiles" "$tmp/"
export PATH="$HOME/.local/bin:$PATH"
bash "$tmp/scripts/link.sh" >/dev/null
if command -v zsh >/dev/null; then
  for mode in -c -lc; do
    result="$(zsh "$mode" 'printf "%s %s\n" "${CODEX_HOME:-default}" "$(node --version)"')"
    [[ "$result" == 'default fixture-node' ]] || { echo "zsh $mode selected $result" >&2; exit 1; }
  done
fi
[[ "$(cat "$HOME/.config/codex/auth.json")" == 'private auth' ]]
bash "$tmp/scripts/link.sh" >/dev/null
if [[ "$(uname -s)" == Linux ]]; then
  dropin="$HOME/.config/systemd/user/t3code.service.d/runtime.conf"
  grep -qx 'UnsetEnvironment=CODEX_HOME' "$dropin"
  runtime_path="$(sed -n 's/^Environment="PATH=\(.*\)"$/\1/p' "$dropin")"
  [[ "$(PATH="$runtime_path" node --version)" == fixture-node ]]
fi
printf 'Shell and service runtimes agree without moving Codex data\n'
