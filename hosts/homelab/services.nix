{ config, lib, pkgs, ... }:
let
  runtime = lib.concatStringsSep ":" config.dotfiles.runtimePaths;
  dropin = ''
    [Service]
    Environment="PATH=${runtime}"
    EnvironmentFile=-%h/.config/agents/env
    UnsetEnvironment=CODEX_HOME
  '';
in {
  imports = [ ../../services/opencode ];
  home.file = {
    ".config/process-compose/process-compose.yaml".source = ../../config/process-compose/process-compose.yaml;
    ".config/systemd/user/t3code.service.d/runtime.conf".text = dropin;
    ".config/systemd/user/opencode-web.service.d/runtime.conf".text = dropin;
  };
  systemd.user.services = {
    process-compose = {
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
  };
}
