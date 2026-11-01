#!/usr/bin/env bash
# Check the shape of profiles/ and roles/, so each role stays a self-contained folder that profiles compose.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0
fail() { printf '%s\n' "$1" >&2; failed=1; }

for profile in "$repo"/profiles/*.txt; do
  name="$(basename "$profile" .txt)"
  [[ "$name" =~ ^[a-z0-9-]+$ ]] || fail "Profile names use lowercase letters, digits, and dashes: $name"
  roles="$(grep -vE '^[[:space:]]*(#|$)' "$profile" || true)"
  [[ "$(head -n 1 <<< "$roles")" == base ]] || fail "Profile $name must list base first"
  [[ -z "$(sort <<< "$roles" | uniq -d)" ]] || fail "Profile $name lists a role twice"
  while IFS= read -r role; do
    [[ -d "$repo/roles/$role" ]] || fail "Profile $name names a missing role: $role"
  done <<< "$roles"
done

for dir in "$repo"/roles/*/; do
  role="$(basename "$dir")"
  for entry in "$dir"* "$dir".[!.]*; do
    [[ -e "$entry" ]] || continue
    case "$(basename "$entry")" in
      home|packages|services|setup.sh) ;;
      *) fail "Role $role holds $(basename "$entry"); a role holds only home/, packages/, services/, and setup.sh" ;;
    esac
  done
  for entry in "$dir"packages/*; do
    [[ -e "$entry" ]] || continue
    case "$(basename "$entry")" in
      apt.txt|extras.txt|npm.txt|Brewfile) ;;
      *) fail "Role $role has an unknown manifest: packages/$(basename "$entry")" ;;
    esac
  done
  # A role's setup runs on its own; reaching into another role couples their order and contents.
  if [[ -f "${dir}setup.sh" ]] && grep -E 'roles/' "${dir}setup.sh" | grep -vqE "roles/${role}/"; then
    fail "Role $role's setup.sh reaches into another role"
  fi
done

# Two roles that link the same file would replace each other's link on every run.
duplicates="$(cd "$repo/roles" && find . -path './*/home/*' ! -type d | cut -d/ -f4- | sort | uniq -d)"
[[ -z "$duplicates" ]] || fail "Several roles link: $duplicates"

# A package tracked by two roles would leave one manifest behind when `package.sh remove` edits the other.
for manifest in apt.txt extras.txt npm.txt Brewfile; do
  duplicates="$(cd "$repo/roles" && cat ./*/packages/"$manifest" 2>/dev/null | grep -vE '^[[:space:]]*(#|$|tap )' | sort | uniq -d || true)"
  [[ -z "$duplicates" ]] || fail "Several roles track in ${manifest}: $duplicates"
done

[[ "$failed" == 0 ]] || exit 1
printf 'Profile and role layout checks passed\n'
