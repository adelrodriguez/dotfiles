{ config, lib }:
let runtime = lib.concatStringsSep ":" config.dotfiles.runtimePaths;
in ''
  [Service]
  Environment="PATH=${runtime}"
  EnvironmentFile=-%h/.config/agents/env
  UnsetEnvironment=CODEX_HOME
''
