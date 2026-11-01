#!/usr/bin/env bash
# Global npm tools from packages/npm.txt, the same on every platform.
source "$(dirname "${BASH_SOURCE[0]}")/../core.sh"

NPMFILE="$PACKAGES_DIR/npm.txt"
# home/.npmrc sets the same prefix, but packages install before the dotfiles are linked.
export NPM_CONFIG_PREFIX="$HOME/.npm-global"

npm_tracked() {
  grep -qxF "$1" "$NPMFILE"
}

ensure_npm() {
  if ! command_exists npm && command_exists fnm; then
    eval "$(fnm env --shell bash)"
    fnm use default >/dev/null
  fi
  command_exists npm || die "npm is not installed. Run: scripts/package.sh install"
}

npm_packages() {
  local action="$1" name="${2:-}" line
  local -a names=()
  if [[ -n "$name" && ! "$name" =~ ^(@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*$ ]]; then
    die "Invalid npm package name: $name"
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] || names+=("$line")
  done < "$NPMFILE"
  case "$action" in
    install)
      ensure_npm
      npm install --global "${names[@]}"
      ;;
    list)
      printf 'npm:\n'; printf '  %s\n' "${names[@]}"
      ;;
    add)
      [[ -n "$name" ]] || die "Usage: scripts/package.sh add <package> npm"
      ensure_npm
      npm install --global "$name"
      if ! npm_tracked "$name"; then
        printf '%s\n' "$name" >> "$NPMFILE"
        sort -u -o "$NPMFILE" "$NPMFILE"
      fi
      ;;
    remove)
      npm_tracked "$name" || die "Package not tracked: $name"
      grep -vxF "$name" "$NPMFILE" > "$NPMFILE.tmp" || true
      mv "$NPMFILE.tmp" "$NPMFILE"
      info "Removed $name from npm.txt"
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
