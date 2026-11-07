{ config, lib, pkgs, machine, ... }:
{
  options.dotfiles = {
    checkout = lib.mkOption { type = lib.types.str; default = machine.checkout; };
    tools = lib.mkOption { type = lib.types.attrsOf lib.types.package; default = { }; };
    npmPackages = lib.mkOption { type = lib.types.attrsOf lib.types.str; default = { }; };
    vendorTools = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "claude" "codex" "grok" "opencode" "t3" "apm" ]);
      default = [ ];
    };
    runtimePaths = lib.mkOption { type = lib.types.listOf lib.types.str; };
    brew = lib.mkOption {
      type = lib.types.submodule { options = lib.genAttrs [ "taps" "brews" "casks" ] (_: lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      }); };
      default = { };
    };
  };
  config = {
    home.packages = lib.unique (builtins.attrValues config.dotfiles.tools);
    home.file = {
      ".config/dotfiles/host".text = machine.host + "\n";
      ".config/dotfiles/checkout".text = config.dotfiles.checkout + "\n";
      ".config/dotfiles/expected.json".text = builtins.toJSON {
        host = machine.host;
        inherit (config.dotfiles) brew npmPackages vendorTools runtimePaths;
        tools = lib.mapAttrs (name: package: "${package}/bin/${name}") config.dotfiles.tools;
      };
      ".config/agents/runtime.path".text = lib.concatLines config.dotfiles.runtimePaths;
    };
    nix.package = lib.mkDefault pkgs.nix;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
  };
}
