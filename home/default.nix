{ config, lib, machine, ... }:
let
  # Their tools write these files, so a read-only store link breaks them. Keep them in mutable.py.
  writable = [
    ".npmrc" ".gitconfig" ".netrc" ".yarnrc.yml" ".docker/config.json" ".aws/credentials"
    ".config/gh/hosts.yml" ".config/fish/fish_variables" ".config/fish/completions/grok.fish"
  ];
  linked = map (file: file.target) (lib.attrValues config.home.file);
in {
  imports = [ ./apps ./shell ./git ];
  home = {
    inherit (machine) username homeDirectory;
    stateVersion = "26.05";
    sessionVariables.EDITOR = "nvim";
  };
  assertions = map (path: {
    assertion = !(lib.elem path linked);
    message = "~/${path} must stay writable because its tool writes it. Manage it in home/mutable.py, not home.file.";
  }) writable;
  programs.home-manager.enable = true;
  # Reload definitions, but leave running agent sessions alone during a switch.
  systemd.user.startServices = "suggest";
}
