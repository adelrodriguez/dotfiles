{ lib, ... }:
let
  files = dir: prefix: lib.listToAttrs (map (file: {
    name = prefix + lib.removePrefix (toString dir + "/") (toString file);
    value.source = file;
  }) (lib.filesystem.listFilesRecursive dir));
in {
  home.file = lib.mkMerge [
    (files ./atuin ".config/atuin/")
    (files ./bat ".config/bat/")
    (files ./direnv ".config/direnv/")
    (files ./fd ".config/fd/")
    {
      ".config/starship.toml".source = ./starship.toml;
      ".ripgreprc".source = ./ripgreprc;
      ".npmrc".source = ./npm/npmrc;
    }
  ];
}
