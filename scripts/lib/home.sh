#!/usr/bin/env bash
# Link the home/ folder of each role in the profile into $HOME with GNU Stow, moving conflicting files to backups/ first.
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/profile.sh"

# Every path that any role links, relative to $HOME. A directory sorts before its contents.
role_paths() {
  local dir
  for dir in "$ROLES_DIR"/*/home; do
    find "$dir" -mindepth 1 | sed "s|^${dir}/||"
  done | sort -u
}

# Remove links into the repository that no longer point at a role's file, such as links into the
# home/ folder of the layout before roles or into a role that dropped the file. Stow relinks the path.
# A folded directory from the old layout becomes a real directory that keeps its untracked files.
prune_links() {
  local rel path target
  while IFS= read -r rel; do
    path="${HOME}/${rel}"
    [[ -L "$path" ]] || continue
    target="$(resolve_link "$path")"
    [[ "$target" == "$DOTFILES_DIR"/* ]] || continue
    [[ "$target" == "$ROLES_DIR"/*/home/"$rel" && -f "$target" ]] && continue
    rm "$path"
    if [[ "$target" == "$DOTFILES_DIR"/home/* && -d "$target" ]]; then
      mkdir "$path"
      find "$target" -mindepth 1 -maxdepth 1 -exec mv {} "$path/" \;
    fi
  done < <(role_paths)
}

# systemctl enable records a linked unit's resolved path, which is inside the repository and dangles once the
# unit file moves. Point each boot link at the unit's link in ~/.config instead, which Stow keeps current.
point_unit_links_home() {
  local units="${HOME}/.config/systemd/user" wants unit
  for wants in "$units"/*.wants/*; do
    [[ -L "$wants" && "$(resolve_link "$wants")" == "$DOTFILES_DIR"/* ]] || continue
    unit="${units}/$(basename "$wants")"
    [[ -L "$unit" && -e "$unit" ]] && ln -sfn "$unit" "$wants"
  done
  return 0
}

backup_conflicts() {
  local role_home="$1"
  local backup_dir="${DOTFILES_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
  local -a conflicts=()
  local file rel target source_resolved target_resolved

  while IFS= read -r -d '' file; do
    rel="${file#"${role_home}"/}"
    target="${HOME}/${rel}"
    [[ -e "$target" || -L "$target" ]] || continue
    [[ "$(resolve_link "$target")" == "$file" ]] && continue
    source_resolved=$(perl -MCwd -e 'print Cwd::abs_path(shift)' "$file" 2>/dev/null || true)
    target_resolved=$(perl -MCwd -e 'print Cwd::abs_path(shift)' "$target" 2>/dev/null || true)
    [[ -n "$source_resolved" && "$source_resolved" == "$target_resolved" ]] && continue
    conflicts+=("$rel")
  done < <(find "$role_home" -type f -print0)

  [[ ${#conflicts[@]} -gt 0 ]] || return 0
  info "Backing up existing files to ${backup_dir}"
  for rel in "${conflicts[@]}"; do
    mkdir -p "$(dirname "${backup_dir}/${rel}")"
    mv "${HOME}/${rel}" "${backup_dir}/${rel}"
  done
}

link_home() {
  command_exists stow || die "GNU Stow is not installed. Run: scripts/install.sh"
  load_profile
  local dir role
  # Stow refuses to unstow through a folded directory from the old layout, so rebuild those first.
  prune_links
  for dir in "$ROLES_DIR"/*/home; do
    role="$(basename "$(dirname "$dir")")"
    has_role "$role" || stow -D --no-folding -d "${ROLES_DIR}/${role}" -t "$HOME" home
  done
  # Without folding, Stow links files into real directories, so several roles can share a directory
  # and secrets written to ~/.config/agents stay out of the repository.
  for role in "${ROLES[@]}"; do
    [[ -d "${ROLES_DIR}/${role}/home" ]] || continue
    backup_conflicts "${ROLES_DIR}/${role}/home"
    stow -R --no-folding -d "${ROLES_DIR}/${role}" -t "$HOME" home
  done
  point_unit_links_home
}
