{ config, ... }:
let
  # tests/nix.py supplies only its temporary directory, username, and message.
  trial = builtins.fromJSON (builtins.getEnv "DOTFILES_NIX_PILOT");
in
{
  home.username = trial.username;
  home.homeDirectory = trial.homeDirectory;
  home.stateVersion = "26.05";
  home.sessionPath = [ "${config.home.profileDirectory}/bin" ];
  home.file.".config/dotfiles-nix-pilot/message".text = trial.message + "\n";
  programs.home-manager.enable = true;
  programs.bash.enable = true;
}
