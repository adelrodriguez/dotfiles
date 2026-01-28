#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.local/bin"
TARGET_LINK="${TARGET_DIR}/dot"

mkdir -p "$TARGET_DIR"
chmod +x "${DOTFILES_DIR}/dot"

if [[ -L "$TARGET_LINK" || -f "$TARGET_LINK" ]]; then
  rm -f "$TARGET_LINK"
fi

ln -s "${DOTFILES_DIR}/dot" "$TARGET_LINK"

printf "dot installed at %s\n" "$TARGET_LINK"
if [[ ":${PATH}:" != *":${TARGET_DIR}:"* ]]; then
  printf "Add %s to your PATH\n" "$TARGET_DIR"
fi
printf "Next: run 'dot init'\n"
