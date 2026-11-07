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

# Put the Node from the nearest .node-version first on PATH, so agent shells
# get the project's Node without `fnm exec`.
# ~/.zprofile calls this again, because `brew shellenv` there puts Homebrew's
# Node back in front for login shells (`zsh -lc`).
use_node_version() {
  local dir=$PWD
  while [[ $dir != / && ! -f $dir/.node-version && ! -f $dir/.nvmrc ]]; do dir=${dir:h}; done
  local version_file=$dir/.node-version
  [[ -f $version_file ]] || version_file=$dir/.nvmrc
  [[ -f $version_file ]] || return 0
  local version=${$(<$version_file)#v}
  # Like fnm, a partial version such as 22 picks the newest installed 22.x.
  local -a bins=(${FNM_DIR:-$HOME/.local/share/fnm}/node-versions/v${version}(|.*)/installation/bin(N/nOn))
  (( $#bins )) && export PATH="$bins[1]:$PATH"
  return 0
}
use_node_version
