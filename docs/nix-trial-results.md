# Nix trial results

The manual trials on November 7, 2026 covered one disposable Ubuntu 24.04.4 x86_64 VM and one macOS 27.0 arm64 workstation. Both used Lix installer 3.95.0, Lix 2.95.2, and Home Manager release 26.05.

Home Manager builds, file-collision protection, activation, repeat activation, invalid-build protection, and generation rollback passed on both machines. Real package commands executed. A Mac shell check also passed after inherited Nix paths and environment markers were removed. The Mac's existing pnpm command and Homebrew formula were preserved.

The package inputs recorded in `flake.lock` are:

| Input | Revision |
| --- | --- |
| Home Manager | `24f2190587513b9c2f73db112a17844ae912d965` |
| Linux nixpkgs | `c56a87d8e41ce69bd2af57eb35dcc117a9dfca33` |
| Darwin nixpkgs | `57f1c8965649ce5bcac5118a0d2e41f1fbdc56e5` |

These historical manual runs used small standalone configurations. The repository now declares the complete host environments. Its host harness uses upstream Nix 2.34.1 and verifies those configurations in disposable homes. The manual pilot results alone do not prove the full migration.

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

The trials did not activate nix-darwin or migrate existing Stow files, services, or credentials. Homebrew version rollback and full machine reproduction were not tested. Installer-source fixes remain outside the dotfiles configuration. No performance benchmark was run.

## Full configuration validation

The replacement configuration was tested on November 7 in a fresh disposable Boat VM running Ubuntu 24.04.4 x86_64 with upstream Nix 2.34.1. The complete homelab Home Manager configuration built and passed collision protection, legacy handoff, activation, repeat activation, generation rollback, and fresh fish and zsh checks. The declared Nix packages, pinned direct npm packages, and native agent CLIs executed from their expected providers. Project Node selection used fnm while the default runtime returned to the pinned Nix Node.

The harness checked unchanged account profiles and an inherited custom Nix state fixture. Deliberately redirecting `NIX_STATE_HOME` back to that inherited fixture made activation fail. The corrected isolated environment completed successfully. A separate migration regression first failed because an old Fisher function remained. The handoff now backs up the files registered to the repository's former plugins, and that check passes.

A separate run exercised `scripts/apply.sh homelab` with the disposable VM account and checkout declared as its machine identity. The apply and runtime installers passed. OpenCode, T3, and Process Compose were enabled and active, their running environments matched the host runtime, and the OpenCode and T3 web roots returned HTTP 200 on loopback. This run used fresh application data, not homelab's existing databases or private route.

The Mac fixture suite passed. The complete nix-darwin system derivation evaluated on the Linux test host. Mac package builds and the generated Homebrew inventory are checked by the Mac CI job. Root-level nix-darwin activation, the homelab private Caddy route, private credentials, and existing application databases remain deployment checks. Neither live machine was changed during this replacement.

## Runtime regression checks

The installed-state checker now observes the caller's PATH instead of replacing it with the declared runtime. Regression fixtures reject shadowed Nix, npm, and vendor commands, including a PATH missing the declared Node. The host test also invokes the doctor through fresh fish and zsh shells and from an fnm project. Service environments are still compared with the declared default runtime.

Additional migration checks cover a Fish directory linked into the old checkout, preservation of unrelated local functions, repeated handoff, and rejection of foreign directory links. The Fish environment check seeds both an inherited global and an exported universal `CODEX_HOME`, then verifies that both the current shell and a new shell have no custom home. These fixtures failed before the fixes and pass afterward on the Mac.

A probe using the evaluated Mac runtime and conflicting provider fixtures selected Homebrew Fish before the fix. After moving the Home Manager profile ahead of Homebrew, the same probe selected Nix Fish while retaining Homebrew pnpm ahead of an old npm-global copy.

The complete Ubuntu host run passed again with these fixes, including doctor checks from fresh fish and zsh shells and from the fnm project. The regression suite also passed using the pinned Linux tool environment. Mac system activation and the new Mac CI result remain unverified at this point.

The first Mac CI run installed its complete Brewfile, then failed provider checks and falsely reported the tapped Axiom cask as missing. The provider order is corrected above. Cask validation now reads Homebrew's installed JSON metadata and matches `full_token`, so a qualified declaration retains its tap identity. The regression rejects a matching short token from another tap and an uninstalled cask. The new case failed before the fix, then the six-case runtime suite and the read-only check against the Mac's real Axiom metadata passed.
