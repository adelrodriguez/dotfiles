{ config, lib, pkgs, inputs, ... }:
let
  fishFiles = lib.filter (file: baseNameOf file != "grok.fish")
    (lib.filesystem.listFilesRecursive ./fish);
in {
  imports = [ ./grok.nix ];
  programs.fish = {
    enable = true;
    package = config.dotfiles.tools.fish;
    plugins = map (name: { inherit name; src = pkgs.fishPlugins.${name}.src; })
      [ "fzf-fish" "done" "pisces" ]
      ++ [ { name = "fish-bang-bang"; src = inputs.fish-bang-bang; } ];
  };
  home.file = lib.listToAttrs (map (file: {
    name = ".config/fish/" + lib.removePrefix (toString ./fish + "/") (toString file);
    value.source = file;
  }) fishFiles) // {
    ".zshenv".source = ./zsh/zshenv;
    ".zprofile".source = ./zsh/zprofile;
    ".zshrc".source = ./zsh/zshrc;
    ".config/zsh/env.zsh".source = ./zsh/env.zsh;
    ".config/zsh/bindings.zsh".source = ./zsh/bindings.zsh;
  };
}
