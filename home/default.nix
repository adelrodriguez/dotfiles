{ machine, ... }:
{
  imports = [ ./apps ./shell ./git ];
  home = {
    inherit (machine) username homeDirectory;
    stateVersion = "26.05";
    sessionVariables.EDITOR = "nvim";
  };
  programs.home-manager.enable = true;
  # Reload definitions, but leave running agent sessions alone during a switch.
  systemd.user.startServices = "suggest";
}
