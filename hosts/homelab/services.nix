{ config, lib, pkgs, ... }:
let
  home = config.home.homeDirectory;
  runtime = lib.concatStringsSep ":" config.dotfiles.runtimePaths;
  dropin = ''
    [Service]
    Environment="PATH=${runtime}"
    EnvironmentFile=-%h/.config/agents/env
    UnsetEnvironment=CODEX_HOME
  '';
in {
  home.file = {
    ".config/process-compose/process-compose.yaml".source = ../../config/process-compose/process-compose.yaml;
    ".config/systemd/user/t3code.service.d/runtime.conf".text = dropin;
    ".config/systemd/user/opencode-web.service.d/runtime.conf".text = dropin;
    "services/opencode/verify.py".source = ../../services/opencode/verify.py;
    "services/opencode/caddy.conf".source = ../../services/opencode/caddy.conf;
  };
  systemd.user.services = {
    opencode-web = {
      Unit = {
        Description = "OpenCode web service";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        WorkingDirectory = "%h";
        Environment = [
          "HOME=%h" "SHELL=${pkgs.bash}/bin/bash" "PATH=${runtime}"
          "XDG_DATA_HOME=%h/services/opencode/runtime/xdg-data"
          "XDG_STATE_HOME=%h/services/opencode/runtime/xdg-state"
          "XDG_CACHE_HOME=%h/services/opencode/runtime/xdg-cache"
          "XDG_RUNTIME_DIR=%t" "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus"
        ];
        ExecStart = "${home}/services/opencode/bin/opencode serve --service --hostname 127.0.0.1 --port 4096";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
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
