{ config, lib, pkgs, ... }:
{
  home.file.".config/git/managed".source = ./config;
  # Credential tools write ~/.gitconfig. Only its managed include belongs to Nix.
  home.activation.gitInclude = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
    run ${pkgs.python3}/bin/python3 ${../mutable.py} git \
      ${lib.escapeShellArg config.home.homeDirectory} \
      ${lib.escapeShellArg config.dotfiles.checkout} ${pkgs.git}/bin/git
  '';
}
