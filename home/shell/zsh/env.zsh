[[ -r "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

unset CODEX_HOME
typeset -U path
typeset -a runtime_paths
runtime_paths=()
while IFS= read -r entry || [[ -n "$entry" ]]; do
  [[ -n "$entry" ]] || continue
  [[ "$OSTYPE" != linux* || "$entry" != /opt/homebrew/* ]] || continue
  [[ "$entry" == /* ]] || entry="$HOME/$entry"
  runtime_paths+=("$entry")
done < "$HOME/.config/agents/runtime.path"
path=("${runtime_paths[@]}")
export PATH

# Use the same fnm resolver as interactive shells. The version-file gate keeps
# Nix's default outside projects, even when fnm has a different default alias.
# Interactive shells select Node through the fnm hook in zshrc instead. A
# directory added here would stay on PATH after the shell leaves the project.
use_node_version() {
  [[ ! -o interactive ]] || return 0
  command -v fnm >/dev/null 2>&1 || return 0
  local dir=$PWD
  while [[ $dir != / && ! -f $dir/.node-version && ! -f $dir/.nvmrc ]]; do dir=${dir:h}; done
  [[ -f $dir/.node-version || -f $dir/.nvmrc ]] || return 0
  local selected
  selected="$(fnm exec --version-file-strategy recursive -- node -p 'process.execPath')" || return
  path=("${selected:h}" "${path[@]}")
  export PATH
}
use_node_version
