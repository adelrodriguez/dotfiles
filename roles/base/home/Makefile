# Machine tasks. Stow links this file to ~/Makefile, so run `make <target>` from ~ or `make -C ~ <target>` from anywhere.
# Resolve the link to find the repository's scripts.
DOTFILES_DIR := $(realpath $(dir $(realpath $(firstword $(MAKEFILE_LIST))))../../..)

.PHONY: agents\:sync agents\:update

# Install, prune, and compile the agent setup in agents/ at the commits in its lock.
agents\:sync:
	"$(DOTFILES_DIR)/scripts/agents.sh" sync

# Move every agent package to the latest commit on its branch, then deploy it.
agents\:update:
	"$(DOTFILES_DIR)/scripts/agents.sh" update
