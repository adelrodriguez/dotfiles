{ lib, ... }:
let
  files = dir: prefix: lib.listToAttrs (map (file: {
    name = prefix + lib.removePrefix (toString dir + "/") (toString file);
    value.source = file;
  }) (lib.filesystem.listFilesRecursive dir));
in {
  home.file = lib.mkMerge [
    (files ../../config/atuin ".config/atuin/")
    (files ../../config/bat ".config/bat/")
    (files ../../config/direnv ".config/direnv/")
    (files ../../config/fd ".config/fd/")
    {
      ".config/starship.toml".source = ../../config/starship.toml;
      ".config/agents/env.tpl".source = ../../config/agents/env.tpl;
      ".ripgreprc".source = ../../config/ripgreprc;
      ".npmrc".source = ../../config/npm/npmrc;
    }
  ];
}
