#!/usr/bin/env bash
set -euo pipefail

PACKAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$HOME/.bun/bin:$HOME/.atuin/bin:$HOME/.opencode/bin:/usr/local/bin:/usr/bin:/bin"
mkdir -p "$HOME/.local/bin"
source "$PACKAGES_DIR/github-release.sh"
source "$PACKAGES_DIR/opencode-v2.sh"

run_installer() {
  local url="$1"
  shift
  local script
  script="$(mktemp)"
  curl -fsSL "$url" -o "$script"
  "${INSTALLER_SHELL:-bash}" "$script" "$@"
  rm -f "$script"
}

use_node() {
  command -v fnm >/dev/null || install_extra fnm
  eval "$(fnm env --shell bash)"
  if ! fnm use default; then
    install_node
  fi
  export PATH="$(npm prefix --global)/bin:$PATH"
}

install_node() {
  local version
  version="$(curl -fsSL https://nodejs.org/dist/index.json | jq -er '.[0].version')"
  fnm install "$version"
  fnm use "$version"
  fnm default "$version"
}

install_fzf() {
  local arch tag tmp
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *) echo 'Unsupported fzf architecture' >&2; return 1 ;;
  esac
  tag="$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest | jq -er .tag_name)"
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/junegunn/fzf/releases/download/$tag/fzf-${tag#v}-linux_$arch.tar.gz" -o "$tmp/fzf.tar.gz"
  tar -xzf "$tmp/fzf.tar.gz" -C "$tmp" fzf
  install -m 755 "$tmp/fzf" "$HOME/.local/bin/fzf"
  rm -rf "$tmp"
}

install_1password() {
  local arch
  arch="$(dpkg --print-architecture)"
  sudo install -d -m 755 /etc/apt/keyrings
  curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | sudo tee /etc/apt/keyrings/1password.asc >/dev/null
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/1password.asc] https://downloads.1password.com/linux/debian/%s stable main\n' "$arch" "$arch" | sudo tee /etc/apt/sources.list.d/1password-cli.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y 1password-cli
}

install_extra() {
  local name="$1" binary="$1"
  case "$name" in
    graphite) binary=gt ;;
    1password-cli) binary=op ;;
    bubblewrap) binary=bwrap ;;
    neovim) binary=nvim ;;
    ripgrep) binary=rg ;;
  esac
  case "$name" in
    bat|btop|bubblewrap|delta|direnv|eza|fd|fish|gh|jq|neovim|ripgrep|tmux|zoxide)
      install_github_release "$name"
      return ;;
    stow) install_stow; return ;;
    git)
      if ! grep -rq 'git-core/ppa' /etc/apt/sources.list.d; then
        sudo add-apt-repository -y ppa:git-core/ppa
      fi
      sudo apt-get update
      sudo env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l apt-get install -y git
      return ;;
  esac
  case "$name" in
    node|pnpm|graphite|pi|vercel|codex) use_node ;;
  esac
  if [[ "${UPDATE:-0}" != 1 ]] && command -v "$binary" >/dev/null &&
    { [[ "$name" != fzf ]] || [[ "$(command -v fzf)" == "$HOME/.local/bin/fzf" ]]; } &&
    { [[ "$name" != atuin ]] || dpkg --compare-versions "$(atuin --version | awk '{print $2}')" ge 18.23.0; }; then
    printf '%s already installed\n' "$name"
    return
  fi
  case "$name" in
    fnm) run_installer https://fnm.vercel.app/install --install-dir "$HOME/.local/share/fnm" --skip-shell ;;
    node) install_node ;;
    bun) run_installer https://bun.sh/install ;;
    claude) run_installer https://claude.ai/install.sh latest ;;
    codex) npm install --global @openai/codex ;;
    grok) SHELL=/bin/sh run_installer https://x.ai/cli/install.sh ;;
    atuin) ATUIN_NO_MODIFY_PATH=1 ATUIN_INSTALL_DIR="$HOME/.atuin/bin" run_installer https://github.com/atuinsh/atuin/releases/latest/download/atuin-installer.sh ;;
    starship) INSTALLER_SHELL=sh run_installer https://starship.rs/install.sh --yes --bin-dir "$HOME/.local/bin" ;;
    fzf) install_fzf ;;
    process-compose) run_installer https://raw.githubusercontent.com/F1bonacc1/process-compose/main/scripts/get-pc.sh -b "$HOME/.local/bin" ;;
    opencode)
      if command -v opencode >/dev/null; then
        opencode upgrade --method curl
      else
        install_opencode_v2
      fi ;;
    pnpm) npm install --global pnpm ;;
    graphite) npm install --global @withgraphite/graphite-cli ;;
    pi) npm install --global @earendil-works/pi-coding-agent ;;
    vercel) npm install --global vercel ;;
    1password-cli) install_1password ;;
    *) printf 'Unknown extra: %s\n' "$name" >&2; return 1 ;;
  esac
}

if [[ $# -gt 0 ]]; then
  for name in "$@"; do install_extra "$name"; done
else
  # Child installers must not consume the remaining manifest through stdin.
  mapfile -t names < "$PACKAGES_DIR/extras.txt"
  for name in "${names[@]}"; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    install_extra "$name" </dev/null
  done
fi
