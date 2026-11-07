#!/usr/bin/env bash
# Fill ~/.config/agents/env from its 1Password template with this machine's service account.
source "$(dirname "${BASH_SOURCE[0]}")/../tools/runtime.sh"

AGENTS_DIR="${HOME}/.config/agents"
AGENTS_ENV="${AGENTS_DIR}/env"
AGENTS_ENV_TEMPLATE="${AGENTS_DIR}/env.tpl"
AGENTS_TOKEN="${AGENTS_DIR}/1password-token"
# Comments, blank lines, and KEY=value lines whose values every reader parses the same way.
AGENTS_ENV_LINE='^(#.*|[A-Za-z_][A-Za-z0-9_]*=[A-Za-z0-9_./:@+,=%-]*)?$'

write_agents_env() {
  command_exists op || die "The 1Password CLI is not installed. Run: scripts/bootstrap.sh"
  [[ -r "$AGENTS_TOKEN" ]] || die "Save this machine's 1Password service account token to ${AGENTS_TOKEN}"

  mkdir -p "$AGENTS_DIR"
  [[ "$(cd -P "$AGENTS_DIR" && pwd)" != "$DOTFILES_DIR"/* ]] \
    || die "${AGENTS_DIR} links into the repository; replace that link with a real directory so secrets stay out of it"
  agents_env_tmp="$(umask 077 && mktemp "${AGENTS_DIR}/.env.XXXXXX")"
  trap 'rm -f "${agents_env_tmp:-}"' EXIT
  local tmp="$agents_env_tmp"

  OP_SERVICE_ACCOUNT_TOKEN="$(<"$AGENTS_TOKEN")" op inject --in-file "$AGENTS_ENV_TEMPLATE" >"$tmp" \
    || die "Could not fill ${AGENTS_ENV_TEMPLATE} from 1Password; kept the existing ${AGENTS_ENV}"
  local invalid
  invalid="$(grep -nvE "$AGENTS_ENV_LINE" "$tmp" | cut -d: -f1 | paste -sd, -)" || true
  [[ -z "$invalid" ]] \
    || die "Lines ${invalid} hold values that systemd and the shells would read differently; kept the existing ${AGENTS_ENV}"

  if [[ -f "$AGENTS_ENV" ]] && cmp -s "$tmp" "$AGENTS_ENV"; then
    chmod 600 "$AGENTS_ENV"
    info "${AGENTS_ENV} is up to date"
  else
    mv "$tmp" "$AGENTS_ENV"
    info "Wrote ${AGENTS_ENV}"
  fi
}
