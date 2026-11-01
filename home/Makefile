# Machine tasks. Stow links this file to ~/Makefile, so run `make <target>` from ~ or `make -C ~ <target>` from anywhere.
APM_DIR := $(HOME)/.apm

.PHONY: agents-sync

# Install, prune, and compile the agent setup from the dotagents clone at user scope.
agents-sync:
	@test -f "$(APM_DIR)/Makefile" || { echo "agents-sync: dotagents is not cloned at $(APM_DIR). See https://github.com/adelrodriguez/dotagents#install-dotagents" >&2; exit 1; }
	@command -v apm >/dev/null || { echo "agents-sync: the apm command is not installed. See https://github.com/adelrodriguez/dotagents#install-dotagents" >&2; exit 1; }
	$(MAKE) -C "$(APM_DIR)" sync
