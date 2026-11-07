{ pkgs, machine, ... }:
{
  nixpkgs.hostPlatform = machine.system;
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = 6;
  system.primaryUser = machine.username;
  users.users.${machine.username} = {
    home = machine.homeDirectory;
    shell = pkgs.fish;
  };
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];
  homebrew = (import ./homebrew.nix) // {
    enable = true;
    # Extra applications and locally installed formulae are user-owned.
    onActivation.cleanup = "none";
    onActivation.autoUpdate = false;
    onActivation.upgrade = false;
  };
}
