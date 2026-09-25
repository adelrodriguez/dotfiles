#!/usr/bin/env bash

# Latest stable GitHub releases, installed separately from Ubuntu's system tools.
install_github_release() (
  set -euo pipefail
  local name="$1" repo pattern binary mode=archive arch cpu metadata url tag tmp root dest executable
  arch="$(uname -m)"
  case "$arch" in
    x86_64) cpu=amd64 ;;
    aarch64) cpu=arm64 ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
  esac
  binary="$name"
  case "$name" in
    bat) repo=sharkdp/bat; pattern="^bat-.*-$arch-unknown-linux-musl.tar.gz$" ;;
    btop) repo=aristocratos/btop; pattern="^btop-$arch-unknown-linux-musl.tar.gz$" ;;
    bubblewrap) repo=containers/bubblewrap; pattern='^bubblewrap-.*\.tar\.xz$'; binary=bwrap; mode=meson ;;
    delta) repo=dandavison/delta; pattern="^delta-.*-$arch-unknown-linux-gnu.tar.gz$" ;;
    direnv) repo=direnv/direnv; pattern="^direnv.linux-$cpu$"; mode=binary ;;
    eza) repo=eza-community/eza; pattern="^eza_$arch-unknown-linux-gnu.tar.gz$" ;;
    fd) repo=sharkdp/fd; pattern="^fd-.*-$arch-unknown-linux-musl.tar.gz$" ;;
    fish) repo=fish-shell/fish-shell; pattern="^fish-.*-linux-$arch.tar.xz$" ;;
    gh) repo=cli/cli; pattern="^gh_.*_linux_$cpu.tar.gz$" ;;
    jq) repo=jqlang/jq; pattern="^jq-linux-$cpu$"; mode=binary ;;
    neovim) repo=neovim/neovim; pattern="^nvim-linux-${arch/aarch64/arm64}.tar.gz$"; binary=nvim ;;
    ripgrep) repo=BurntSushi/ripgrep; pattern="^ripgrep-.*-$arch-unknown-linux-musl.tar.gz$"; binary=rg ;;
    tmux) repo=tmux/tmux; pattern='^tmux-.*\.tar\.gz$'; mode=configure ;;
    zoxide) repo=ajeetdsouza/zoxide; pattern="^zoxide-.*-$arch-unknown-linux-musl.tar.gz$" ;;
    *) echo "Unknown GitHub tool: $name" >&2; exit 1 ;;
  esac
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://api.github.com/repos/$repo/releases/latest" -o "$tmp/release.json"
  tag="$(jq -er .tag_name "$tmp/release.json")"
  url="$(jq -er --arg pattern "$pattern" '[.assets[] | select(.name | test($pattern)) | .browser_download_url] | if length == 1 then .[0] else error("Expected exactly one release asset") end' "$tmp/release.json")"
  dest="$HOME/.local/share/dot-tools/$name/$tag"
  if [[ ! -f "$dest/$binary" || ! -x "$dest/$binary" ]]; then
    printf 'Installing %s %s\n' "$name" "$tag"
    curl -fsSL "$url" -o "$tmp/download"
    mkdir "$tmp/unpacked"
    if [[ "$mode" == binary ]]; then
      cp "$tmp/download" "$tmp/unpacked/$binary"
      chmod +x "$tmp/unpacked/$binary"
    else
      tar -xf "$tmp/download" -C "$tmp/unpacked"
    fi
    if [[ "$mode" == configure || "$mode" == meson ]]; then
      root="$(find "$tmp/unpacked" -mindepth 1 -maxdepth 1 -type d)"
      if [[ "$mode" == configure ]]; then
        (cd "$root"; ./configure --prefix="$dest"; make -j2; make install)
      else
        meson setup "$root/build" "$root" --prefix="$dest" -Dman=disabled
        ninja -C "$root/build" -j2
        ninja -C "$root/build" install
      fi
      ln -s "bin/$binary" "$dest/$binary"
    else
      # Preserve runtime files (especially Neovim's share/nvim) beside the binary.
      executable="$(find "$tmp/unpacked" -type f -name "$binary" | head -n 1)"
      [[ -n "$executable" ]] || { echo "Missing $binary in release" >&2; exit 1; }
      if [[ -e "$dest" ]]; then mv "$dest" "$dest.incomplete.$(date +%s)"; fi
      mkdir -p "$dest/payload"
      cp -a "$tmp/unpacked/." "$dest/payload/"
      executable="${executable#"$tmp/unpacked/"}"
      ln -s "payload/$executable" "$dest/$binary"
    fi
  fi
  # Replace links atomically, including old batcat/fdfind aliases.
  ln -sfn "$dest/$binary" "$HOME/.local/bin/$binary.new"
  mv -Tf "$HOME/.local/bin/$binary.new" "$HOME/.local/bin/$binary"
)

install_stow() (
  set -euo pipefail
  local tmp version dest
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL https://ftp.gnu.org/gnu/stow/ -o "$tmp/index"
  version="$(grep -oE 'stow-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' "$tmp/index" | sort -Vu | tail -1)"
  [[ -n "$version" ]]
  dest="$HOME/.local/share/dot-tools/stow/${version%.tar.gz}"
  if [[ ! -x "$dest/bin/stow" ]]; then
    curl -fsSL "https://ftp.gnu.org/gnu/stow/$version" -o "$tmp/stow.tar.gz"
    tar -xf "$tmp/stow.tar.gz" -C "$tmp"
    cd "$tmp/${version%.tar.gz}"
    ./configure --prefix="$dest"
    make -j2
    make install
  fi
  ln -sfn "$dest/bin/stow" "$HOME/.local/bin/stow"
)
