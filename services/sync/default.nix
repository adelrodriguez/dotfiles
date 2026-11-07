{ config, lib, pkgs, ... }:
let runtime = lib.concatStringsSep ":" config.dotfiles.runtimePaths;
in {
  imports = [ ../default.nix ];
  home.file = {
    ".config/process-compose/process-compose.yaml".source = ./process-compose.yaml;
    ".local/bin/dotfiles-sync" = { source = ./dotfiles-sync; executable = true; };
  };
  systemd.user.services.process-compose = {
      Unit = {
        Description = "Dotfiles scheduled sync";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Environment = [ "HOME=%h" "PATH=${runtime}" ];
        ExecStart = "${pkgs.process-compose}/bin/process-compose --port 10080 up --tui=false --keep-project --disable-dotenv --config %h/.config/process-compose/process-compose.yaml";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
}
