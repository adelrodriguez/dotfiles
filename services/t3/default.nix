{ config, lib, ... }:
{
  imports = [ ../default.nix ];
  dotfiles.externalServices = [ "t3code" ];
  home.file.".config/systemd/user/t3code.service.d/runtime.conf".text =
    import ../environment.nix { inherit config lib; };
}
