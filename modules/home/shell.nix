{ config, lib, pkgs, inputs, ... }:
let
  fishFiles = lib.filter (file: baseNameOf file != "grok.fish")
    (lib.filesystem.listFilesRecursive ../../config/fish);
in {
  programs.fish = {
    enable = true;
    package = config.dotfiles.tools.fish;
    plugins = map (name: { inherit name; src = pkgs.fishPlugins.${name}.src; })
      [ "fzf-fish" "done" "pisces" ]
      ++ [ { name = "fish-bang-bang"; src = inputs.fish-bang-bang; } ];
  };
  home.file = lib.listToAttrs (map (file: {
    name = ".config/fish/" + lib.removePrefix (toString ../../config/fish + "/") (toString file);
    value.source = file;
  }) fishFiles) // {
    ".zshenv".source = ../../config/zsh/zshenv;
    ".zprofile".source = ../../config/zsh/zprofile;
    ".zshrc".source = ../../config/zsh/zshrc;
    ".config/zsh/env.zsh".source = ../../config/zsh/env.zsh;
    ".config/zsh/bindings.zsh".source = ../../config/zsh/bindings.zsh;
  };
}
