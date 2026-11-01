# Every zsh reads this file, including the non-interactive shells that agents run.
if [[ -r "$HOME/.config/agents/env" ]]; then
  set -a
  source "$HOME/.config/agents/env"
  set +a
fi
