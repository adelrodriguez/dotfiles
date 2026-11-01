#!/usr/bin/env bash
# Exercise the agent environment setup and its shell loaders in an isolated home with 1Password replaced by a stub.
set -euo pipefail
source_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$tmp"' EXIT
repo="$tmp/repo"
mkdir -p "$repo"
cp -R "$source_repo/scripts" "$source_repo/home" "$repo/"
export HOME="$tmp/home"
export CALLS="$tmp/calls"
env_file="$HOME/.config/agents/env"
mkdir -p "$HOME/.local/bin" "$HOME/.config"
# Linking a fresh home, then linking it again, keeps ~/.config/agents a real directory.
bash "$repo/scripts/link.sh"
bash "$repo/scripts/link.sh"
[[ -d "$HOME/.config/agents" && ! -L "$HOME/.config/agents" && -L "$HOME/.config/agents/env.tpl" ]]
# Each op:// reference becomes value-<field>. OP_MODE=fail fails and OP_MODE=space adds a space to the values.
cat > "$HOME/.local/bin/op" <<'SH'
#!/bin/bash
printf 'op %s token=%s\n' "$1" "${OP_SERVICE_ACCOUNT_TOKEN:-unset}" >> "$CALLS"
[[ "${OP_MODE:-}" == fail ]] && exit 1
suffix=""
[[ "${OP_MODE:-}" == space ]] && suffix=" with space"
sed -E "s|op://[^/]+/[^/]+/(.*)$|value-\1${suffix}|" "$3"
SH
# Each unit runs the process whose PID is in $PIDS/<unit>, or is stopped.
export PIDS="$tmp/pids"
mkdir -p "$PIDS"
cat > "$HOME/.local/bin/systemctl" <<'SH'
#!/bin/bash
printf 'systemctl %s\n' "$*" >> "$CALLS"
if [[ "$2" == show && "$3" == -p ]]; then
  cat "$PIDS/$6" 2>/dev/null || echo 0
fi
SH
chmod +x "$HOME/.local/bin/"{op,systemctl}
setup() { bash -c 'source "$1/scripts/lib/agents-env.sh"; setup_agents_env' _ "$repo"; }
write() { bash "$repo/scripts/agents-env.sh"; }

# Without a token, setup skips and the command fails.
setup | grep -q '^Skipping agent environment'
if write 2>/dev/null; then exit 1; fi
[[ ! -e "$env_file" ]]

printf 'test-token\n' > "$HOME/.config/agents/1password-token"
setup
[[ "$(stat -c %a "$env_file")" == 600 ]]
grep -qx 'FILE_UPLOAD_BUCKET=value-bucket' "$env_file"
grep -qx 'op inject token=test-token' "$CALLS"
grep -qx 'systemctl --user daemon-reload' "$CALLS"
if grep -q 'restart' "$CALLS"; then exit 1; fi
[[ -z "$(find "$HOME/.config/agents" -name '.env.*')" ]]

# A second run leaves the file untouched.
before="$(stat -c %Y:%i "$env_file")"
write | grep -q 'is up to date'
[[ "$(stat -c %Y:%i "$env_file")" == "$before" ]]

# Services restart only when their running process lacks the values, even when the file is unchanged.
sleep 60 & echo $! > "$PIDS/opencode-web.service"
sleep 60 & echo $! > "$PIDS/t3code.service"
: > "$CALLS"
write | grep -q '^Restart t3code.service'
grep -qx 'systemctl --user restart opencode-web.service' "$CALLS"
mapfile -t values < <(grep -v '^#' "$env_file" | grep .)
env "${values[@]}" sleep 60 & echo $! > "$PIDS/opencode-web.service"
env "${values[@]}" sleep 60 & echo $! > "$PIDS/t3code.service"
: > "$CALLS"
if write | grep -q '^Restart'; then exit 1; fi
if grep -q restart "$CALLS"; then exit 1; fi

# Failed or unsafe output keeps the existing file and never prints a value.
expected="$(cat "$env_file")"
if OP_MODE=fail write 2>/dev/null; then exit 1; fi
if OP_MODE=space write 2>"$tmp/err"; then exit 1; fi
if grep -q value- "$tmp/err"; then exit 1; fi
[[ "$(cat "$env_file")" == "$expected" ]]
[[ -z "$(find "$HOME/.config/agents" -name '.env.*')" ]]

# A folded link into the repository never receives secrets.
mv "$HOME/.config/agents" "$tmp/agents"
ln -s "$repo/home/.config/agents" "$HOME/.config/agents"
cp "$tmp/agents/1password-token" "$repo/home/.config/agents/"
if write 2>/dev/null; then exit 1; fi
[[ ! -e "$repo/home/.config/agents/env" ]]
rm "$HOME/.config/agents" "$repo/home/.config/agents/1password-token"
mv "$tmp/agents" "$HOME/.config/agents"

# Each loader exports every value and never the 1Password token.
printf 'AGENTS_DASH=-dash\n' >> "$env_file"
check='[[ "$FILE_UPLOAD_SECRET_ACCESS_KEY" == value-secret_access_key && "$AGENTS_DASH" == -dash && -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]'
if command -v zsh >/dev/null; then
  zsh -c "bash -c '$check'"
  # ~/.zshenv also sets up the PATH that agent shells need, and ~/.zprofile calls use_node_version.
  [[ -z "$(zsh -c 'typeset -f use_node_version >/dev/null && [[ ":$PATH:" == *":$HOME/.npm-global/bin:"* ]] || echo missing' 2>&1)" ]]
  # A partial .node-version picks the newest installed match from fnm's directory, as fnm does.
  project="$tmp/project/src"
  mkdir -p "$project" "$tmp/fnm/node-versions/"{v22.9.0,v22.10.0,v220.0.0}/installation/bin
  printf '22\n' > "$tmp/project/.node-version"
  first_path="$(cd "$project" && FNM_DIR="$tmp/fnm" zsh -c 'print -r -- ${path[1]}')"
  [[ "$first_path" == "$tmp/fnm/node-versions/v22.10.0/installation/bin" ]]
fi
if command -v fish >/dev/null; then
  fish --no-config -c "source '$repo/home/.config/fish/conf.d/00-env.fish'; bash -c '$check'"
fi
printf 'Agent environment checks passed\n'
