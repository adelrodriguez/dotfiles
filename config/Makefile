# Run from ~, or use make -C ~ agents:sync from any directory.
DOTFILES_DIR := $(shell cat "$(HOME)/.config/dotfiles/checkout")
.PHONY: agents\:sync agents\:update
agents\:sync:
	"$(DOTFILES_DIR)/scripts/agents.sh" sync
agents\:update:
	"$(DOTFILES_DIR)/scripts/agents.sh" update
