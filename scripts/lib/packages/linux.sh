#!/usr/bin/env bash
# Ubuntu packages: APT from packages/linux/apt.txt, upstream tools through extras.sh.
source "$(dirname "${BASH_SOURCE[0]}")/../core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/extras.sh"

APTFILE="$PACKAGES_DIR/linux/apt.txt"

linux_packages() {
  [[ -f /etc/os-release ]] || die "Linux package installation requires Ubuntu"
  local ID
  . /etc/os-release
  [[ "$ID" == ubuntu ]] || die "Linux package installation currently supports Ubuntu only"
  local action="$1" name="${2:-}" type="${3:-apt}"
  if [[ -n "$name" && ! "$name" =~ ^[a-z0-9][a-z0-9+.-]*$ ]]; then
    die "Invalid package name: $name"
  fi
  local -a packages=()
  mapfile -t packages < <(grep -vE '^\s*(#|$)' "$APTFILE")
  case "$action" in
    install)
      sudo apt-get update
      sudo apt-get install -y "${packages[@]}"
      install_extras
      ;;
    list)
      printf 'apt:\n'; sed 's/^/  /' "$APTFILE"
      printf 'upstream:\n'; sed 's/^/  /' "$EXTRASFILE"
      ;;
    add)
      [[ "$name" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || die "Usage: scripts/package.sh add <package> [apt]"
      [[ "$type" == apt ]] || die "Add upstream installers to scripts/lib/packages/extras.sh and packages/linux/extras.txt"
      sudo apt-get update
      sudo apt-get install -y "$name"
      if ! grep -qxF "$name" "$APTFILE"; then
        printf '%s\n' "$name" >> "$APTFILE"
        sort -u -o "$APTFILE" "$APTFILE"
      fi
      ;;
    remove)
      [[ -n "$name" ]] || die "Usage: scripts/package.sh remove <package>"
      if grep -qxF "$name" "$EXTRASFILE"; then
        sed -i "/^${name//./\\.}$/d" "$EXTRASFILE"
        info "Removed $name from extras.txt. Uninstall it using its upstream tool if needed."
      else
        grep -qxF "$name" "$APTFILE" || die "Package not tracked: $name"
        sed -i "/^${name//./\\.}$/d" "$APTFILE"
        if confirm "Uninstall ${name} from system?" n; then sudo apt-get remove -y "$name"; fi
      fi
      ;;
    update)
      if [[ -n "$name" ]] && grep -qxF "$name" "$EXTRASFILE"; then
        UPDATE=1 install_extras "$name"
      else
        if [[ -n "$name" ]]; then
          grep -qxF "$name" "$APTFILE" || die "Package not tracked: $name"
          packages=("$name")
        fi
        sudo apt-get update
        sudo apt-get install -y "${packages[@]}"
        if [[ -z "$name" ]]; then UPDATE=1 install_extras; fi
      fi
      ;;
    *) die "Usage: scripts/package.sh <install|add|remove|update|list>" ;;
  esac
}
