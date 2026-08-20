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

4. Install `dot`.

	```sh
	./install.sh
	```

	The script prints the path to `dot`. If `~/.local/bin` is not in `PATH`, the script tells you to add it.

5. Initialize the machine.

	```sh
	"$HOME/.local/bin/dot" init
	```

	`dot init` installs Homebrew when needed. It then installs `packages/bundle`, links the dotfiles, and configures the shell and scheduled tasks. A successful run ends with `Done`.
