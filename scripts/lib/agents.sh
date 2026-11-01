#!/usr/bin/env bash
# Deploy the agent setup in agents/ with APM at user scope.
# APM reads its manifest only from a regular ~/.apm/apm.yml, so the sync copies the files in rather than linking them.
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

AGENTS_SOURCE_DIR="${DOTFILES_DIR}/agents"
APM_DIR="${HOME}/.apm"
APM_FILES=(apm.yml apm.lock.yaml)

# Replace the destination with a regular copy of the source unless it already is one.
copy_if_changed() {
  local source="$1" destination="$2"
  [[ ! -L "$destination" ]] && cmp -s "$source" "$destination" && return 0
  rm -f "$destination"
  cp "$source" "$destination"
  info "Copied ${source} to ${destination}"
}

# Deploy agents/ with `sync` at the locked commits or `update` to the latest ones.
# The repository's copies change only when every APM command succeeds.
deploy_agents() {
  local install
  case "$1" in
    sync) install=(apm install --global) ;;
    update) install=(apm update --global --yes) ;;
    *) die "Unknown agents command: $1. Use sync or update." ;;
  esac
  command_exists apm || die "The apm command is not installed. See ${DOTFILES_DIR}/docs/agents.md#install-apm"
  [[ ! -L "$APM_DIR" ]] || die "${APM_DIR} is a symlink, which APM refuses. Replace it with a real directory."
  [[ ! -e "${APM_DIR}/.git" ]] \
    || die "${APM_DIR} is still a dotagents clone. See ${DOTFILES_DIR}/docs/agents.md#move-from-dotagents"

  # The deployed lock is the only record of what to remove after a pull, so never overwrite it with a different lock.
  [[ ! -e "${APM_DIR}/apm.lock.yaml" ]] || cmp -s "${APM_DIR}/apm.lock.yaml" "${AGENTS_SOURCE_DIR}/apm.lock.yaml" \
    || die "agents/apm.lock.yaml differs from the deployed lock. Follow \"Update after a pull\" in ${AGENTS_SOURCE_DIR}/AGENTS.md first."

  mkdir -p "$APM_DIR"
  local file
  for file in "${APM_FILES[@]}"; do
    copy_if_changed "${AGENTS_SOURCE_DIR}/${file}" "${APM_DIR}/${file}"
  done

  # apm prune reads the manifest from the current directory. `||` turns off errexit, so chain each step with `&&`.
  (cd "$APM_DIR" && "${install[@]}" && apm prune && apm compile --global) \
    || die "APM failed; kept ${AGENTS_SOURCE_DIR} unchanged"

  for file in "${APM_FILES[@]}"; do
    copy_if_changed "${APM_DIR}/${file}" "${AGENTS_SOURCE_DIR}/${file}"
  done
}
