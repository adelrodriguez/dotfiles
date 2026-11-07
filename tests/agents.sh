#!/usr/bin/env bash
# Exercise `make agents:sync` and `make agents:update` in an isolated home with APM replaced by a stub.
set -euo pipefail
source_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
mkdir -p "$repo"
cp -R "$source_repo/scripts" "$source_repo/config" "$source_repo/agents" "$repo/"
export HOME="$tmp/home"
export CALLS="$tmp/calls"
mkdir -p "$HOME/.local/bin" "$HOME/.config/dotfiles" "$tmp/bin"
printf "server\n" > "$HOME/.config/dotfiles/profile"

# Link every command on PATH except apm, so the test controls whether APM exists and which one runs.
IFS=: read -ra path_dirs <<< "$PATH"
for dir in "${path_dirs[@]}"; do
  for command in "$dir"/*; do
    name="${command##*/}"
    [[ -x "$command" && ! -d "$command" && "$name" != apm && ! -e "$tmp/bin/$name" ]] && ln -s "$command" "$tmp/bin/$name"
  done
done
export PATH="$HOME/.local/bin:$tmp/bin"
printf "%s\n" "$repo" > "$HOME/.config/dotfiles/checkout"
ln -s "$repo/config/Makefile" "$HOME/Makefile"
[[ -L "$HOME/Makefile" ]]
agents() { make --no-print-directory -s -C "$HOME" "agents:$1"; }

# Without APM, the sync fails before it creates ~/.apm.
if agents sync 2>/dev/null; then exit 1; fi
[[ ! -e "$HOME/.apm" ]]

# Each call records its arguments and directory. APM_MODE=fail fails the install, APM_MODE=fail-prune fails prune, APM_MODE=prune-edits makes prune rewrite the lock, and an update rewrites the lock the way APM does.
cat > "$HOME/.local/bin/apm" <<'SH'
#!/bin/bash
printf 'apm %s in %s\n' "$*" "$PWD" >> "$CALLS"
[[ "$1" == install && "${APM_MODE:-}" == fail ]] && exit 1
[[ "$1" == prune && "${APM_MODE:-}" == fail-prune ]] && exit 1
[[ "$1" == prune && "${APM_MODE:-}" == prune-edits ]] && printf '# pruned\n' >> apm.lock.yaml
if [[ "$1" == update ]]; then
  { cat apm.lock.yaml; printf '# updated\n'; } > apm.lock.yaml.tmp
  mv apm.lock.yaml.tmp apm.lock.yaml
fi
exit 0
SH
chmod +x "$HOME/.local/bin/apm"

# A dotagents clone at ~/.apm stops the sync before APM runs.
mkdir -p "$HOME/.apm/.git"
if agents sync 2>/dev/null; then exit 1; fi
[[ ! -e "$CALLS" && ! -e "$HOME/.apm/apm.yml" ]]
rm -rf "$HOME/.apm"

# A sync copies regular files into ~/.apm, runs every step there, and leaves the repository unchanged.
agents sync >/dev/null
for file in apm.yml apm.lock.yaml; do
  [[ -f "$HOME/.apm/$file" && ! -L "$HOME/.apm/$file" ]]
  cmp -s "$HOME/.apm/$file" "$source_repo/agents/$file"
  cmp -s "$repo/agents/$file" "$source_repo/agents/$file"
done
diff <(printf 'apm %s in %s\n' 'install --global' "$HOME/.apm" prune "$HOME/.apm" 'compile --global' "$HOME/.apm") "$CALLS"

# A second sync copies nothing.
if agents sync | grep -q '^Copied'; then exit 1; fi

# A symlinked manifest, which APM refuses, becomes a regular copy.
rm "$HOME/.apm/apm.yml"
ln -s "$repo/agents/apm.yml" "$HOME/.apm/apm.yml"
agents sync >/dev/null
[[ -f "$HOME/.apm/apm.yml" && ! -L "$HOME/.apm/apm.yml" ]]

# A failed install stops before prune and keeps the repository's lock.
: > "$CALLS"
if APM_MODE=fail agents sync 2>/dev/null; then exit 1; fi
grep -q '^apm install' "$CALLS"
if grep -q prune "$CALLS"; then exit 1; fi
cmp -s "$repo/agents/apm.lock.yaml" "$source_repo/agents/apm.lock.yaml"

# An update installs again before prune, and brings the new lock back into the repository.
: > "$CALLS"
agents update >/dev/null
diff <(printf 'apm %s in %s\n' 'update --global --yes' "$HOME/.apm" 'install --global' "$HOME/.apm" prune "$HOME/.apm" 'compile --global' "$HOME/.apm") "$CALLS"
[[ "$(tail -n 1 "$repo/agents/apm.lock.yaml")" == '# updated' ]]
cmp -s "$HOME/.apm/apm.lock.yaml" "$repo/agents/apm.lock.yaml"

# An update whose prune fails still brings the new lock back, so a retry is not mistaken for a pull.
if APM_MODE=fail-prune agents update 2>/dev/null; then exit 1; fi
cmp -s "$HOME/.apm/apm.lock.yaml" "$repo/agents/apm.lock.yaml"
agents sync >/dev/null

# A lock that prune rewrites also comes back, so the next sync still runs.
APM_MODE=prune-edits agents sync >/dev/null
[[ "$(tail -n 1 "$repo/agents/apm.lock.yaml")" == '# pruned' ]]
agents sync >/dev/null

# After a pull changes the lock, the sync stops before APM runs and keeps the deployed lock for the cleanup.
deployed="$(cat "$HOME/.apm/apm.lock.yaml")"
printf '# pulled\n' >> "$repo/agents/apm.lock.yaml"
: > "$CALLS"
if agents sync 2>"$tmp/err"; then exit 1; fi
grep -q 'Update after a pull' "$tmp/err"
[[ ! -s "$CALLS" && "$(cat "$HOME/.apm/apm.lock.yaml")" == "$deployed" ]]

# The script rejects other commands.
if bash "$repo/scripts/agents.sh" deploy 2>/dev/null; then exit 1; fi
printf 'Agent setup checks passed\n'
