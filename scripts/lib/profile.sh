#!/usr/bin/env bash
# The machine's profile: the roles in profiles/<name>.txt, recorded once per machine in ~/.config/dotfiles/profile.
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

PROFILE_FILE="${HOME}/.config/dotfiles/profile"

profile_names() {
  local file
  for file in "$PROFILES_DIR"/*.txt; do
    basename "$file" .txt
  done | paste -sd '|' -
}

# Record this machine's profile. The next load_profile reads it.
profile_set() {
  local name="$1"
  [[ "$name" =~ ^[a-z0-9-]+$ && -f "${PROFILES_DIR}/${name}.txt" ]] \
    || die "Unknown profile: ${name}. Choose one of: $(profile_names)"
  # A ~/.config folded by the home/ layout dangles once a pull removes its directory. link_home rebuilds it.
  if [[ -L "$HOME/.config" && ! -e "$HOME/.config" && "$(resolve_link "$HOME/.config")" == "$DOTFILES_DIR"/* ]]; then
    rm "$HOME/.config"
  fi
  mkdir -p "$(dirname "$PROFILE_FILE")"
  printf '%s\n' "$name" > "$PROFILE_FILE"
}

# Machines linked before profiles existed get the profile their OS implied.
# Delete this once every machine has a ~/.config/dotfiles/profile.
legacy_profile() {
  [[ "$(resolve_link "$HOME/.gitconfig")" == "${DOTFILES_DIR}/home/.gitconfig" ]] || return 1
  case "$PLATFORM" in
    Linux) printf 'server\n' ;;
    Darwin) printf 'mac\n' ;;
    *) return 1 ;;
  esac
}

# Set PROFILE and ROLES from the recorded profile. Call it in the main shell, so a missing profile stops the command.
load_profile() {
  local legacy role
  if [[ ! -f "$PROFILE_FILE" ]]; then
    legacy="$(legacy_profile)" || die "No profile recorded. Run: scripts/install.sh <$(profile_names)>"
    profile_set "$legacy"
    info "Recorded the ${legacy} profile in ${PROFILE_FILE}"
  fi
  PROFILE="$(<"$PROFILE_FILE")"
  [[ -f "${PROFILES_DIR}/${PROFILE}.txt" ]] || die "Unknown profile in ${PROFILE_FILE}: ${PROFILE}"
  ROLES=()
  while IFS= read -r role || [[ -n "$role" ]]; do
    [[ -z "$role" || "$role" == \#* ]] && continue
    [[ -d "${ROLES_DIR}/${role}" ]] || die "Profile ${PROFILE} names a missing role: ${role}"
    ROLES+=("$role")
  done < "${PROFILES_DIR}/${PROFILE}.txt"
}

has_role() {
  local role
  for role in ${ROLES[@]+"${ROLES[@]}"}; do
    [[ "$role" == "$1" ]] && return 0
  done
  return 1
}

# Print each active role's manifest with this file name, in profile order.
role_manifests() {
  local role
  for role in ${ROLES[@]+"${ROLES[@]}"}; do
    [[ -f "${ROLES_DIR}/${role}/packages/$1" ]] && printf '%s\n' "${ROLES_DIR}/${role}/packages/$1"
  done
  return 0
}

# Print the manifest that `package add --role` writes the entry to, creating it when the role has none yet.
# Each package belongs to one role, so remove and update find the only manifest that tracks it.
role_manifest() {
  local role="$1" file="$2" entry="$3" tracked
  has_role "$role" || die "Role ${role} is not in the ${PROFILE} profile"
  if tracked="$(manifest_tracking "$file" "$entry")" && [[ "$tracked" != "${ROLES_DIR}/${role}/packages/${file}" ]]; then
    die "${entry} is already tracked in ${tracked#"$DOTFILES_DIR"/}"
  fi
  mkdir -p "${ROLES_DIR}/${role}/packages"
  touch "${ROLES_DIR}/${role}/packages/${file}"
  printf '%s\n' "${ROLES_DIR}/${role}/packages/${file}"
}

# Print the first active manifest with this file name that tracks the line.
manifest_tracking() {
  local file
  while IFS= read -r file; do
    if grep -qxF "$2" "$file"; then
      printf '%s\n' "$file"
      return 0
    fi
  done < <(role_manifests "$1")
  return 1
}

# Print the entries of every active manifest with this file name, without comments or blank lines.
manifest_entries() {
  local file
  while IFS= read -r file; do
    grep -vE '^[[:space:]]*(#|$)' "$file" || true
  done < <(role_manifests "$1")
}
