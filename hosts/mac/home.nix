{ config, pkgs, ... }:
{
  imports = [ ../../modules/home ];
  dotfiles = {
    brew = import ./packages.nix;
    tools = {
      node = pkgs.nodejs_26;
      fish = pkgs.fish;
      bash = pkgs.bash;
      python3 = pkgs.python3;
    };
    npmPackages = {
      "@antfu/ni" = "30.6.0";
      "@earendil-works/pi-coding-agent" = "1.5.0";
      "agent-browser" = "0.41.2";
      "agent-desktop" = "1.2.0";
      "packref" = "0.3.7";
      "vercel" = "65.12.1";
    };
    runtimePaths = [
      "${pkgs.nodejs_26}/bin"
      "${config.home.profileDirectory}/bin"
      "/opt/homebrew/bin" "/opt/homebrew/sbin"
      "${config.home.homeDirectory}/.npm-global/bin"
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.bun/bin"
      "${config.home.homeDirectory}/.opencode/bin"
      "${config.home.homeDirectory}/.cargo/bin"
      "/run/current-system/sw/bin" "/nix/var/nix/profiles/default/bin"
      "/usr/local/bin" "/usr/bin" "/bin" "/usr/sbin" "/sbin"
    ];
  };
}
