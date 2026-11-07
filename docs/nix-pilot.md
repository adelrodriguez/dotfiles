# How to run the Nix pilot

This guide shows you how to verify the pinned Home Manager pilot in a disposable home. It builds and activates real packages, changes a managed file, and proves rollback and removal.

## Run the checks

1. Use a disposable x86_64 Ubuntu VM or arm64 Mac with Python 3.9 or newer and a running multi-user Nix installation. The daemon socket must be `/nix/var/nix/daemon-socket/socket`. CI provides Nix 2.34.1 on Ubuntu 24.04 and macOS 15 with [install-nix-action](https://github.com/cachix/install-nix-action).

   Read the [workstation trial findings](nix-trial-results.md) before installing Nix on a daily machine.

2. From the checkout, run:

   ```sh
   python3 tests/nix.py
   ```

   Each build, activation, and removal step prints its name before starting. Failed commands report their output and exit nonzero.

3. Check that the command ends with:

   ```text
   Nix pilot passed. The disposable home and client state were removed.
   ```

   The check verifies installed jq and hello commands, package selection in a fresh Bash login shell, local-file protection, repeat activation, a rejected invalid build, generation rollback, and Home Manager removal. It also compares the account's existing Nix profiles before and after the run.

The temporary home, copied configuration, and client state are removed after success or failure. Downloaded packages remain in the shared Nix store for normal garbage collection. The command does not install or uninstall Nix itself.

## Inspect or update the inputs

The pilot files are:

| Path | Purpose |
| --- | --- |
| `nix/flake.nix` | Independent `server` and `mac` package declarations, using the Linux and Darwin package sets. |
| `nix/flake.lock` | Pinned Home Manager and nixpkgs inputs from the manual trials. |
| `nix/home.nix` | Shared disposable file and Bash configuration. |
| `tests/nix.py` | The build, activation, rollback, removal, and isolation checks. |

To update the inputs in a Nix-enabled disposable environment, run:

```sh
nix --extra-experimental-features 'nix-command flakes' flake update --flake ./nix
python3 tests/nix.py
```

Commit the resulting lockfile only after the checks pass on both platforms. Builds use `--no-update-lock-file` and reject unrecorded input changes.

The harness supplies `DOTFILES_NIX_PILOT` as JSON containing its temporary home, current username, and test message. `--impure` reads those test parameters. Package inputs remain pinned by the lockfile. The harness sets separate XDG directories and `NIX_STATE_DIR`, while connecting explicitly to the existing store daemon. This keeps Home Manager's legacy-profile migration inside the disposable state directory. Changing only `HOME` would leave that migration able to find the account's legacy profile.

## Scope

The pilot uses no agent credentials or production dotfiles. The two host declarations currently install Bash, hello, and jq. Each host owns its package selection.

The existing installation scripts, Stow ownership, APM deployment, agent services, and pnpm ownership remain unchanged. Returning Mac pnpm to Homebrew is a requirement for a later production migration. This pilot does not assert that the current production machine installations meet that requirement.

CI activates the pilot and checks its observed result. It does not verify a complete dotfiles installation, workstation uninstall behavior, or nix-darwin activation.
