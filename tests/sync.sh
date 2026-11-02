#!/usr/bin/env bash
# Sync a clone from a remote whose next commit changes the linker, and check that the pulled linker runs.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME"
git() { command git -c user.name=test -c user.email=test@example.invalid -c init.defaultBranch=main "$@"; }

git init -q "$tmp/origin"
cp -R "$repo/scripts" "$repo/roles" "$repo/profiles" "$tmp/origin/"
git -C "$tmp/origin" add -A
git -C "$tmp/origin" commit -qm initial
git clone -q "$tmp/origin" "$tmp/clone"

printf '#!/usr/bin/env bash\ntouch "$HOME/pulled-linker-ran"\n' > "$tmp/origin/scripts/link.sh"
git -C "$tmp/origin" commit -qam 'change the linker'

bash "$tmp/clone/scripts/sync.sh" >/dev/null
[[ -e "$HOME/pulled-linker-ran" ]]
printf 'Sync links with the pulled scripts\n'
