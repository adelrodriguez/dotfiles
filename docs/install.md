# Install the dotfiles

These steps install the repository at `~/Developer/dotfiles` and link its configuration into `$HOME`.

1. Create the parent directory.

	```sh
	mkdir -p "$HOME/Developer"
	```

2. Clone the repository.

	```sh
	git clone https://github.com/adelrodriguez/dotfiles.git "$HOME/Developer/dotfiles"
	```

3. Open the repository directory.

	```sh
	cd "$HOME/Developer/dotfiles"
	```

4. Set up the machine with its profile. Use `server` for an Ubuntu server or VPS, or `mac` for a macOS workstation.

	```sh
	scripts/install.sh server
	```

	`scripts/install.sh` records the profile in `~/.config/dotfiles/profile`, so later runs need no profile name. On macOS, it installs Homebrew when needed and installs each role's `packages/Brewfile`. On Ubuntu, it installs each role's `packages/apt.txt` with APT and runs the upstream installers listed in each role's `packages/extras.txt`. Ubuntu installation requires sudo access. fnm manages Node; no Linuxbrew or mise installation is needed.

	It then links the dotfiles, sets fish as the account's default shell, and configures scheduled tasks. A successful run ends with `Done`. Start a new terminal session to use fish after the default shell changes.
