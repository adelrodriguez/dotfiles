#!/usr/bin/env bash
# Global npm tools from each role's npm.txt, the same on every platform.
source "$(dirname "${BASH_SOURCE[0]}")/../core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../profile.sh"

# home/.npmrc sets the same prefix, but packages install before the dotfiles are linked.
export NPM_CONFIG_PREFIX="$HOME/.npm-global"

npm_tracked() {
  manifest_tracking npm.txt "$1" >/dev/null
}

ensure_npm() {
  if ! command_exists npm && command_exists fnm; then
    eval "$(fnm env --shell bash)"
    fnm use default >/dev/null
  fi
  command_exists npm || die "npm is not installed. Run: scripts/package.sh install"
}

npm_packages() {
  local action="$1" name="${2:-}" role="${3:-base}" npmfile line
  local -a names=()
  if [[ -n "$name" && ! "$name" =~ ^(@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*$ ]]; then
    die "Invalid npm package name: $name"
  fi
  while IFS= read -r line; do
    names+=("$line")
  done < <(manifest_entries npm.txt)
  case "$action" in
    install)
      ensure_npm
      npm install --global "${names[@]}"
      ;;
    list)
      printf 'npm:\n'; printf '  %s\n' "${names[@]}"
      ;;
    add)
      [[ -n "$name" ]] || die "Usage: scripts/package.sh add <package> npm [--role <role>]"
      npmfile="$(role_manifest "$role" npm.txt "$name")"
      ensure_npm
      npm install --global "$name"
      if ! grep -qxF "$name" "$npmfile"; then
        printf '%s\n' "$name" >> "$npmfile"
        sort -u -o "$npmfile" "$npmfile"
      fi
      ;;
    remove)
      npmfile="$(manifest_tracking npm.txt "$name")" || die "Package not tracked: $name"
      grep -vxF "$name" "$npmfile" > "$npmfile.tmp" || true
      mv "$npmfile.tmp" "$npmfile"
      info "Removed $name from ${npmfile#"$DOTFILES_DIR"/}"
      if confirm "Uninstall ${name} from system?" n; then
        ensure_npm
        npm uninstall --global "$name"
      fi
      ;;
    update)
      ensure_npm
      if [[ -n "$name" ]]; then
        names=("$name")
      fi
      npm install --global "${names[@]/%/@latest}"
      ;;
    *) die "Usage: scripts/package.sh <install|add|remove|update|list>" ;;
  esac
}
