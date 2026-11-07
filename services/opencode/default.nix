{ config, lib, pkgs, ... }:
let
  home = config.home.homeDirectory;
  runtime = lib.concatStringsSep ":" config.dotfiles.runtimePaths;
in {
  imports = [ ../default.nix ];
  home.file = {
    ".config/systemd/user/opencode-web.service.d/runtime.conf".text = import ../environment.nix { inherit config lib; };
    "services/opencode/verify.py".source = ./verify.py;
    "services/opencode/caddy.conf".source = ./caddy.conf;
  };
  systemd.user.services.opencode-web = {
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
}
