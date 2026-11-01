[[ -r "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# npm global installs (prefix in ~/.npmrc), shared by every Node version
export PATH="$HOME/.npm-global/bin:$PATH"

# Put the Node from the nearest .node-version first on PATH, so agent shells
# get the project's Node and its corepack pnpm without `fnm exec`.
# ~/.zprofile calls this again, because `brew shellenv` there puts Homebrew's
# Node back in front for login shells (`zsh -lc`).
use_node_version() {
  local dir=$PWD
  while [[ $dir != / && ! -f $dir/.node-version ]]; do dir=${dir:h}; done
  [[ -f $dir/.node-version ]] || return 0
  local bin=$HOME/.local/share/fnm/node-versions/v${$(<$dir/.node-version)#v}/installation/bin
  [[ -d $bin ]] && export PATH="$bin:$PATH"
  return 0
}
use_node_version
