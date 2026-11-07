# How to install or migrate the dotfiles

This guide shows you how to replace the native installer and Stow links with the declared Nix environment. Use the production checkout on `main` after the PR merges. Do not activate a feature worktree on a live host.

## Prepare the checkout

1. Use `/Users/adelrodriguez/Developer/dotfiles` on the Mac or `/home/adel/dotfiles` on homelab. For a different account or checkout, update `hosts/<host>/machine.nix` first. The apply command checks the checkout path before changing files.
2. Commit or save local configuration edits. The handoff backs up conflicting target files under `~/.local/state/dotfiles/backups/`, but private databases and application state still need their normal backups.
3. On the Mac, install [Homebrew](https://brew.sh) if missing. On Ubuntu, provide `curl`, Git, Python 3, CA certificates, and xz through the distribution before bootstrapping. Ubuntu 24.04 is the tested Linux base.

## Build and apply

If Nix is already installed, build first:

```sh
scripts/apply.sh mac --build
# On homelab:
scripts/apply.sh homelab --build
```

To install Nix if needed and provision the host:

```sh
scripts/bootstrap.sh mac
# On homelab:
scripts/bootstrap.sh homelab
```

The Nix installer requests administrator access. On macOS it creates the Nix Store volume at `/nix`. nix-darwin activation also requires administrator access. Linux bootstrap registers fish as the login shell and enables user lingering so services survive logout. Follow the installer's Terminal prompts directly.

The first apply builds before moving any legacy file. It replaces checkout links with Home Manager links, preserves private agent files and local Git credentials, and records the host and checkout under `~/.config/dotfiles/`. It does not uninstall unlisted Homebrew formulae or casks.

For an existing nix-darwin file conflict under `/etc`, inspect the named file and preserve a copy before moving it aside. Do not force activation over unknown system files. The manual Nix installer trials did not exercise root-level nix-darwin activation. See the [recorded results and installer issues](nix-trial-results.md).

## Verify the host

Start a fresh fish or zsh login shell, then run:

```sh
scripts/doctor.sh
make -C ~ agents:sync
```

The doctor reports missing tools, unexpected providers, unsafe private file permissions, and stopped Linux services. Restore homelab's private OpenCode and Caddy credentials before testing its public route, as described in [the service guide](agent-services.md). Reauthenticate Codex in its default `~/.codex` home when needed.

To populate agent variables, save the host's 1Password service-account token as the regular file `~/.config/agents/1password-token`, set mode 0600, and run `scripts/agents-env.sh`. Never add the token or generated environment to Git.

## Update and roll back

Edit packages in the owning host module. Add shared configuration and its Home Manager declaration in the owning domain. See the [architecture reference](architecture.md). Stage new files before Nix evaluates a Git checkout, because flakes exclude untracked files.

Update the pinned inputs and rebuild through a PR:

```sh
nix flake update
scripts/apply.sh mac --build
# Or scripts/apply.sh homelab --build
```

Both hosts currently declare `pkgs.nodejs_26` as their base Node. To pick up newer Node 26 releases from the pinned channels, update those inputs and rebuild:

```sh
nix flake update nixpkgs-linux nixpkgs-darwin
scripts/apply.sh mac --build
# Or scripts/apply.sh homelab --build
```

For a future major upgrade, change `dotfiles.tools.node` in each host's `home.nix` and update the lockfile. The runtime paths derive from those package declarations. CI checks the selected base binary and confirms that leaving a project returns to that base.

After merging, `scripts/sync.sh` fast-forwards and activates the new generation. Apply installs missing vendor tools and changed npm versions. Use each vendor's supported update command for an installed self-updating CLI. Homebrew updates are deliberate, for example `brew upgrade pnpm`.

On homelab, list previous configurations with `home-manager generations` and run the selected generation's `activate` script. On the Mac, use `sudo darwin-rebuild switch --rollback`. Restore mutable runtime data separately if an application update changed it. To return to native dotfiles, remove Home Manager's managed links and restore the backup files before running the previous repository revision. Nix uninstall is a separate system operation, including its macOS volume. Do not delete `/nix` by hand.
