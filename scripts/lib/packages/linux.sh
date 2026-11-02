#!/usr/bin/env bash
# Ubuntu packages: APT from each role's apt.txt, upstream tools through extras.sh.
source "$(dirname "${BASH_SOURCE[0]}")/../core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../profile.sh"
source "$(dirname "${BASH_SOURCE[0]}")/extras.sh"

linux_packages() {
  [[ -f /etc/os-release ]] || die "Linux package installation requires Ubuntu"
  local ID
  . /etc/os-release
  [[ "$ID" == ubuntu ]] || die "Linux package installation currently supports Ubuntu only"
  local action="$1" name="${2:-}" type="${3:-apt}" role="${4:-base}" aptfile extrasfile
  if [[ -n "$name" && ! "$name" =~ ^[a-z0-9][a-z0-9+.-]*$ ]]; then
    die "Invalid package name: $name"
  fi
  local -a packages=()
  mapfile -t packages < <(manifest_entries apt.txt)
  case "$action" in
    install)
      sudo apt-get update
      sudo apt-get install -y "${packages[@]}"
      install_extras
      ;;
    list)
      printf 'apt:\n'; printf '  %s\n' "${packages[@]}"
      printf 'upstream:\n'; manifest_entries extras.txt | sed 's/^/  /'
      ;;
    add)
      [[ "$name" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || die "Usage: scripts/package.sh add <package> [apt|npm] [--role <role>]"
      [[ "$type" == apt ]] || die "Add upstream installers to scripts/lib/packages/extras.sh and a role's packages/extras.txt"
      aptfile="$(role_manifest "$role" apt.txt "$name")"
      sudo apt-get update
      sudo apt-get install -y "$name"
      if ! grep -qxF "$name" "$aptfile"; then
        printf '%s\n' "$name" >> "$aptfile"
        sort -u -o "$aptfile" "$aptfile"
      fi
      ;;
    remove)
      [[ -n "$name" ]] || die "Usage: scripts/package.sh remove <package>"
      if extrasfile="$(manifest_tracking extras.txt "$name")"; then
        sed -i "/^${name//./\\.}$/d" "$extrasfile"
        info "Removed $name from ${extrasfile#"$DOTFILES_DIR"/}. Uninstall it using its upstream tool if needed."
      else
        aptfile="$(manifest_tracking apt.txt "$name")" || die "Package not tracked: $name"
        sed -i "/^${name//./\\.}$/d" "$aptfile"
        if confirm "Uninstall ${name} from system?" n; then sudo apt-get remove -y "$name"; fi
      fi
      ;;
    update)
      if [[ -n "$name" ]] && manifest_tracking extras.txt "$name" >/dev/null; then
        UPDATE=1 install_extras "$name"
      else
        if [[ -n "$name" ]]; then
          manifest_tracking apt.txt "$name" >/dev/null || die "Package not tracked: $name"
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
