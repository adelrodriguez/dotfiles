# Nix trial results

The manual trials on November 7, 2026 covered one disposable Ubuntu 24.04.4 x86_64 VM and one macOS 27.0 arm64 workstation. Both used Lix installer 3.95.0, Lix 2.95.2, and Home Manager release 26.05.

Home Manager builds, file-collision protection, activation, repeat activation, invalid-build protection, and generation rollback passed on both machines. Real package commands executed. A Mac shell check also passed after inherited Nix paths and environment markers were removed. The Mac's existing pnpm command and Homebrew formula were preserved.

The package inputs recorded in `nix/flake.lock` are:

| Input | Revision |
| --- | --- |
| Home Manager | `24f2190587513b9c2f73db112a17844ae912d965` |
| Linux nixpkgs | `c56a87d8e41ce69bd2af57eb35dcc117a9dfca33` |
| Darwin nixpkgs | `57f1c8965649ce5bcac5118a0d2e41f1fbdc56e5` |

These manual runs used small standalone configurations. The committed pilot adds a disposable home and profile-state isolation. Its CI runs use upstream Nix 2.34.1 and verify the committed implementation on Ubuntu and macOS.

## Installer findings

The passing Home Manager checks did not prove that system installation and removal were complete.

| Finding | Observed recovery | Tracking |
| --- | --- | --- |
| The Ubuntu uninstaller removed the store and unit files but left a systemd socket listening in memory. | Stop the socket and reload systemd. The trial VM was then deleted. | [#54](https://github.com/adelrodriguez/dotfiles/issues/54) |
| The Mac's generated repair hook referenced `/nix/lix-installer`, while the installed executable was `/nix/nix-installer`. | The hook was recorded and removed with the trial. Repair across a restart or OS upgrade was not tested. | [#55](https://github.com/adelrodriguez/dotfiles/issues/55) |
| The Mac uninstaller stalled after unmounting its volume, leaving the volume and mount configuration. | Interrupt it, identify the trial volume by its recorded UUID, and remove that volume and the matching temporary mount entries. | [#56](https://github.com/adelrodriguez/dotfiles/issues/56) |
| The Mac shell files retained their original contents and ownership but had mode 0644 instead of their original 0444. | Restore the recorded modes and rerun the same cleanup checks. | [#57](https://github.com/adelrodriguez/dotfiles/issues/57) |

The first Mac background installation also failed while renaming `/etc/fstab.tmp` to `/etc/fstab`. Its privacy-authorization request failed in the elevated background context. Running the reviewed installer through a normal Terminal session succeeded after the partial setup was removed. The trial scripts changed no privacy or System Integrity Protection settings.

## Final state and limits

The captured Mac file contents, ownership, and permissions were restored. The trial volume, services, build accounts, profiles, caches, and managed files were removed. The dotfiles checkout remained clean. The empty synthetic `/nix` mount point remains until the next restart, as described by macOS `synthetic.conf(5)`.

The trials did not activate nix-darwin or migrate existing Stow files, services, or credentials. Homebrew version rollback and full machine reproduction were not tested. Installer-source fixes remain outside this pilot. No performance benchmark was run.
