{ config, lib, ... }:
{
  options.dotfiles.externalServices = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "User services whose main unit is owned by a vendor.";
  };
  config.home.file.".config/dotfiles/services.json".text = builtins.toJSON
    (lib.unique (builtins.attrNames config.systemd.user.services ++ config.dotfiles.externalServices));
}
