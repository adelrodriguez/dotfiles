#!/usr/bin/env bash
# macOS packages from packages/macos/Brewfile.
source "$(dirname "${BASH_SOURCE[0]}")/../core.sh"

BREWFILE="$PACKAGES_DIR/macos/Brewfile"

ensure_homebrew() {
  if command_exists brew; then
    eval "$(brew shellenv)"
    return 0
  fi

  info "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  local -a brew_bins=(
    "/opt/homebrew/bin/brew"
    "/usr/local/bin/brew"
  )
  local brew_bin=""

  for brew_bin in "${brew_bins[@]}"; do
    if [[ -x "$brew_bin" ]]; then
      eval "$("$brew_bin" shellenv)"
      return 0
    fi
  done

  die "Homebrew installed but brew binary was not found in a supported path"
}

ensure_brewfile() {
  if [[ ! -f "$BREWFILE" ]]; then
    die "Missing Brewfile at ${BREWFILE}"
  fi
}

parse_brewfile() {
  TAPS=()
  BREWS=()
  CASKS=()
  OTHERS=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      tap\ "*") TAPS+=("$line") ;;
      brew\ "*") BREWS+=("$line") ;;
      cask\ "*") CASKS+=("$line") ;;
      *) OTHERS+=("$line") ;;
    esac
  done < "$BREWFILE"
}

sort_unique_lines() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  printf "%s\n" "$@" | awk 'NF' | sort -u
}

write_brewfile() {
  {
    if [[ ${#TAPS[@]} -gt 0 ]]; then
      sort_unique_lines "${TAPS[@]}"
      printf "\n"
    fi
    if [[ ${#BREWS[@]} -gt 0 ]]; then
      sort_unique_lines "${BREWS[@]}"
      printf "\n"
    fi
    if [[ ${#CASKS[@]} -gt 0 ]]; then
      sort_unique_lines "${CASKS[@]}"
      printf "\n"
    fi
    if [[ ${#OTHERS[@]} -gt 0 ]]; then
      printf "%s\n" "${OTHERS[@]}"
    fi
  } > "$BREWFILE"
}

brewfile_has_line() {
  local needle="$1"
  local current_line
  while IFS= read -r current_line || [[ -n "$current_line" ]]; do
    [[ "$current_line" == "$needle" ]] && return 0
  done < "$BREWFILE"
  return 1
}

macos_package_install() {
  ensure_homebrew
  ensure_brewfile
  brew bundle --file "$BREWFILE"
}

macos_package_add() {
  local name="${1:-}"
  local type="${2:-brew}"

  [[ -z "$name" ]] && die "Usage: scripts/package.sh add <name> [brew|cask]"
  [[ "$type" != "brew" && "$type" != "cask" ]] && die "Invalid type: $type"

  ensure_homebrew
  ensure_brewfile
  parse_brewfile

  local line="${type} \"${name}\""
  if brewfile_has_line "$line"; then
    warn "Already in Brewfile: ${line}"
  else
    if [[ "$type" == "brew" ]]; then
      BREWS+=("$line")
    else
      CASKS+=("$line")
    fi
    write_brewfile
    info "Added ${line}"
  fi

  if [[ "$type" == "brew" ]]; then
    brew install "$name"
  else
    brew install --cask "$name"
  fi
}

macos_package_remove() {
  local name="${1:-}"
  [[ -z "$name" ]] && die "Usage: scripts/package.sh remove <name>"

  ensure_homebrew
  ensure_brewfile
  parse_brewfile

  local brew_line="brew \"${name}\""
  local cask_line="cask \"${name}\""
  local found="false"

  if brewfile_has_line "$brew_line"; then
    found="true"
  fi
  if brewfile_has_line "$cask_line"; then
    found="true"
  fi
  [[ "$found" == "false" ]] && die "Package not found in Brewfile: ${name}"

  local -a new_brews=()
  for line in "${BREWS[@]}"; do
    [[ "$line" == "$brew_line" ]] || new_brews+=("$line")
  done
  if [[ ${#new_brews[@]} -gt 0 ]]; then
    BREWS=("${new_brews[@]}")
  else
    BREWS=()
  fi

  local -a new_casks=()
  for line in "${CASKS[@]}"; do
    [[ "$line" == "$cask_line" ]] || new_casks+=("$line")
  done
  if [[ ${#new_casks[@]} -gt 0 ]]; then
    CASKS=("${new_casks[@]}")
  else
    CASKS=()
  fi

  write_brewfile
  info "Removed ${name} from Brewfile"

  if confirm "Uninstall ${name} from system?" "n"; then
    if brew list --formula 2>/dev/null | grep -qFx "$name"; then
      brew uninstall "$name" || true
    fi
    if brew list --cask 2>/dev/null | grep -qFx "$name"; then
      brew uninstall --cask "$name" || true
    fi
  fi
}

macos_package_update() {
  local name="${1:-}"
  ensure_homebrew
  ensure_brewfile

  if [[ -z "$name" ]]; then
    brew update
    brew upgrade
    return 0
  fi

  brew upgrade "$name" || brew install "$name"
}

macos_package_list() {
  ensure_brewfile
  parse_brewfile

  if [[ ${#TAPS[@]} -gt 0 ]]; then
    info "taps:"
    printf "%s\n" "${TAPS[@]}" | sed 's/^tap "\(.*\)"$/  \1/'
  fi

  if [[ ${#BREWS[@]} -gt 0 ]]; then
    info "brew:"
    printf "%s\n" "${BREWS[@]}" | sed 's/^brew "\(.*\)"$/  \1/'
  fi

  if [[ ${#CASKS[@]} -gt 0 ]]; then
    info "cask:"
    printf "%s\n" "${CASKS[@]}" | sed 's/^cask "\(.*\)"$/  \1/'
  fi
}

macos_packages() {
  local action="${1:-}"
  shift || true

  case "$action" in
    install) macos_package_install ;;
    add) macos_package_add "$@" ;;
    remove) macos_package_remove "$@" ;;
    update) macos_package_update "$@" ;;
    list) macos_package_list ;;
    *) die "Usage: scripts/package.sh <install|add|remove|update|list>" ;;
  esac
}
