#!/usr/bin/env bash
# Link home/ into $HOME with GNU Stow, moving conflicting files to backups/ first.
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

backup_conflicts() {
  local backup_dir="${DOTFILES_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
  local -a conflicts=()

  add_conflict() {
    local rel="$1"
    local existing
    for existing in "${conflicts[@]-}"; do
      [[ "$existing" == "$rel" ]] && return 0
    done
    conflicts+=("$rel")
  }

  if [[ ! -d "$HOME_DIR" ]]; then
    die "Missing home directory at ${HOME_DIR}"
  fi

  while IFS= read -r -d '' file; do
    local rel="${file#"${HOME_DIR}"/}"
    local target="${HOME}/${rel}"
    local source_resolved
    local target_resolved

    if [[ -e "$target" || -L "$target" ]]; then
      source_resolved=$(perl -MCwd -e 'print Cwd::abs_path(shift)' "$file" 2>/dev/null || true)
      target_resolved=$(perl -MCwd -e 'print Cwd::abs_path(shift)' "$target" 2>/dev/null || true)

      if [[ -n "$source_resolved" && "$source_resolved" == "$target_resolved" ]]; then
        continue
      fi

      if [[ -L "$target" ]]; then
        local resolved
        resolved=$(perl -MCwd -e 'print Cwd::abs_path(shift)' "$target" 2>/dev/null || true)
        if [[ "$resolved" == "${HOME_DIR}"/* ]]; then
          continue
        fi
      fi

      add_conflict "$rel"
    fi
  done < <(find "$HOME_DIR" -type f -print0)

  if [[ ${#conflicts[@]} -eq 0 ]]; then
    return 0
  fi

  info "Backing up existing files to ${backup_dir}"
  for rel in "${conflicts[@]}"; do
    local src="${HOME}/${rel}"
    local dst="${backup_dir}/${rel}"

    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
  done
}

link_home() {
  command_exists stow || die "GNU Stow is not installed. Run: scripts/install.sh"
  backup_conflicts
  stow -R -d "$DOTFILES_DIR" -t "$HOME" home
}
