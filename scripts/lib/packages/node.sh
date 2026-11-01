#!/usr/bin/env bash
# Node through fnm. The latest stable release becomes the default on every platform.
source "$(dirname "${BASH_SOURCE[0]}")/../core.sh"

install_node() {
  local version
  version="$(curl -fsSL https://nodejs.org/dist/index.json | jq -er 'first(.[] | select(.version | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))).version')"
  eval "$(fnm env --shell bash)"
  fnm install "$version"
  fnm use "$version"
  fnm default "$version"
}

use_node() {
  eval "$(fnm env --shell bash)"
  if ! fnm use default; then
    install_node
  fi
  export PATH="$(npm prefix --global)/bin:$PATH"
}
