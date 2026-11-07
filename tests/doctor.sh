#!/usr/bin/env bash
# Doctor must inspect drift, leave user files alone, and succeed after reconciliation.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -R "$repo/scripts" "$repo/roles" "$repo/profiles" "$repo/agents" "$tmp/"
export HOME="$tmp/home"
mkdir -p "$HOME/.config/dotfiles" "$HOME/.local/bin" "$HOME/.apm" "$HOME/.agents/skills/example"
case "$(uname -s)" in Linux) profile=server ;; *) profile=mac ;; esac
printf '%s\n' "$profile" > "$HOME/.config/dotfiles/profile"
for manifest in Brewfile extras.txt npm.txt apt.txt; do : > "$tmp/roles/base/packages/$manifest"; done
printf 'unchanged user skill\n' > "$HOME/.agents/skills/example/SKILL.md"
digest="$(python3 -c 'import hashlib,pathlib; print(hashlib.sha256((pathlib.Path.home()/".agents/skills/example/SKILL.md").read_bytes()).hexdigest())')"
printf 'dependencies:\n- deployed_file_hashes:\n    .agents/skills/example/SKILL.md: sha256:%s\n' "$digest" > "$tmp/agents/apm.lock.yaml"
cp "$tmp/agents/"apm* "$HOME/.apm/"
cat > "$HOME/.local/bin/systemctl" <<'SH'
#!/bin/sh
printf 'ActiveState=inactive\nMainPID=0\n'
SH
chmod +x "$HOME/.local/bin/systemctl"
export PATH="$HOME/.local/bin:$PATH"
bash "$tmp/scripts/link.sh" >/dev/null
doctor() { bash "$tmp/scripts/doctor.sh"; }
doctor > "$tmp/out"
grep -q 'No drift found' "$tmp/out"
printf '# pulled lock\n' >> "$tmp/agents/apm.lock.yaml"
printf 'local user edit\n' > "$HOME/.agents/skills/example/SKILL.md"
rm "$HOME/.zshrc"
if doctor > "$tmp/out"; then echo 'Doctor missed drift' >&2; exit 1; fi
grep -q 'agent lock' "$tmp/out"
grep -q 'example/SKILL.md' "$tmp/out"
grep -q '.zshrc' "$tmp/out"
[[ "$(cat "$HOME/.agents/skills/example/SKILL.md")" == 'local user edit' ]]
[[ ! -e "$HOME/.zshrc" ]]
if CODEX_HOME="$HOME/.config/codex" doctor > "$tmp/out"; then exit 1; fi
grep -q 'CODEX_HOME' "$tmp/out"
printf 'Doctor detects drift and preserves local edits\n'
