{ config, pkgs, inputs, ... }:
{
  imports = [ ../../modules/home ./services.nix ];
  dotfiles = {
    tools = {
      node = pkgs.nodejs_26;
      pnpm = pkgs.pnpm;
      fish = pkgs.fish;
      zsh = pkgs.zsh;
      bash = pkgs.bash;
      python3 = pkgs.python3;
      git = pkgs.git;
      gh = pkgs.gh;
      jq = pkgs.jq;
      rg = pkgs.ripgrep;
      fd = pkgs.fd;
      bat = pkgs.bat;
      btop = pkgs.btop;
      delta = pkgs.delta;
      direnv = pkgs.direnv;
      eza = pkgs.eza;
      fnm = pkgs.fnm;
      fzf = pkgs.fzf;
      nvim = pkgs.neovim;
      starship = pkgs.starship;
      zoxide = pkgs.zoxide;
      # The existing history database requires Atuin >= 18.23.0.
      atuin = inputs.nixpkgs-tools.legacyPackages.${pkgs.stdenv.hostPlatform.system}.atuin;
      bun = pkgs.bun;
      uv = pkgs.uv;
      op = pkgs._1password-cli;
      bwrap = pkgs.bubblewrap;
      process-compose = pkgs.process-compose;
      curl = pkgs.curl;
      tar = pkgs.gnutar;
      unzip = pkgs.unzip;
      make = pkgs.gnumake;
      cc = pkgs.gcc;
      autoconf = pkgs.autoconf;
      automake = pkgs.automake;
      gettext = pkgs.gettext;
      meson = pkgs.meson;
      ninja = pkgs.ninja;
      pkg-config = pkgs.pkg-config;
    };
    npmPackages = {
      "@antfu/ni" = "30.6.0";
      "@earendil-works/pi-coding-agent" = "1.5.0";
      "agent-browser" = "0.41.2";
      "agent-desktop" = "1.2.0";
      "packref" = "0.3.7";
      "vercel" = "65.12.1";
    };
    vendorTools = [ "claude" "codex" "grok" "opencode" "t3" "apm" ];
    runtimePaths = [
      "${config.dotfiles.tools.node}/bin"
      "${config.home.profileDirectory}/bin"
      "${config.home.homeDirectory}/.npm-global/bin"
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.opencode/bin"
      "${config.home.homeDirectory}/.bun/bin"
      "${config.home.homeDirectory}/.cargo/bin"
      "/nix/var/nix/profiles/default/bin"
      "/usr/local/bin" "/usr/bin" "/bin" "/usr/sbin" "/sbin"
    ];
  };
  assertions = [ {
    assertion = pkgs.lib.versionAtLeast config.dotfiles.tools.atuin.version "18.23.0";
    message = "Homelab Atuin must read the history database migrated by Linuxbrew (>= 18.23.0).";
  } ];
  home.packages = [ pkgs.cacert pkgs.libcap pkgs.libseccomp ];
}
