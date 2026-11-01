#!/usr/bin/env bash
# Exercise the agent environment setup and its shell loaders in an isolated home with 1Password replaced by a stub.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
export CALLS="$tmp/calls"
env_file="$HOME/.config/agents/env"
mkdir -p "$HOME/.local/bin" "$HOME/.config/agents" "$HOME/.config/fish/conf.d"
# Each op:// reference becomes value-<field>. OP_MODE=fail fails and OP_MODE=space adds a space to the values.
cat > "$HOME/.local/bin/op" <<'SH'
#!/bin/bash
printf 'op %s token=%s\n' "$1" "${OP_SERVICE_ACCOUNT_TOKEN:-unset}" >> "$CALLS"
[[ "${OP_MODE:-}" == fail ]] && exit 1
suffix=""
[[ "${OP_MODE:-}" == space ]] && suffix=" with space"
sed -E "s|op://[^/]+/[^/]+/(.*)$|value-\1${suffix}|" "$3"
SH
cat > "$HOME/.local/bin/systemctl" <<'SH'
#!/bin/bash
printf 'systemctl %s\n' "$*" >> "$CALLS"
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
grep -qx 'systemctl --user try-restart opencode-web.service' "$CALLS"
[[ -z "$(find "$HOME/.config/agents" -name '.env.*')" ]]

# A second run leaves the file untouched and restarts nothing.
before="$(stat -c %Y:%i "$env_file")"
: > "$CALLS"
write | grep -q 'is up to date'
[[ "$(stat -c %Y:%i "$env_file")" == "$before" ]]
if grep -q try-restart "$CALLS"; then exit 1; fi

# Failed or unsafe output keeps the existing file and never prints a value.
expected="$(cat "$env_file")"
if OP_MODE=fail write 2>/dev/null; then exit 1; fi
if OP_MODE=space write 2>"$tmp/err"; then exit 1; fi
if grep -q value- "$tmp/err"; then exit 1; fi
[[ "$(cat "$env_file")" == "$expected" ]]
[[ -z "$(find "$HOME/.config/agents" -name '.env.*')" ]]

# Each loader exports every value and never the 1Password token.
check='[[ "$FILE_UPLOAD_SECRET_ACCESS_KEY" == value-secret_access_key && -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]'
cp "$repo/home/.zshenv" "$HOME/.zshenv"
bash -c "source \"\$HOME/.zshenv\" && bash -c '$check'"
if command -v zsh >/dev/null; then
  zsh -c "bash -c '$check'"
fi
if command -v fish >/dev/null; then
  fish --no-config -c "source '$repo/home/.config/fish/conf.d/00-env.fish'; bash -c '$check'"
fi
printf 'Agent environment checks passed\n'
