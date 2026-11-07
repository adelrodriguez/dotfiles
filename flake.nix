{
  description = "Machine-owned Mac and homelab environments";
  inputs = {
    nixpkgs-linux.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    fish-bang-bang = { url = "github:nyarly/fish-bang-bang"; flake = false; };
    nixpkgs-tools.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-linux";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";
  };
  outputs = inputs@{ home-manager, nix-darwin, nixpkgs-linux, nixpkgs-darwin, ... }:
    let
      machines = {
        mac = {
          host = "mac";
          username = "adelrodriguez";
          homeDirectory = "/Users/adelrodriguez";
          checkout = "/Users/adelrodriguez/Developer/dotfiles";
          system = "aarch64-darwin";
        };
        homelab = {
          host = "homelab";
          username = "adel";
          homeDirectory = "/home/adel";
          checkout = "/home/adel/dotfiles";
          system = "x86_64-linux";
        };
      };
      mkHome = host: overrides:
        let machine = machines.${host} // overrides;
        in home-manager.lib.homeManagerConfiguration {
          pkgs = import (if host == "mac" then nixpkgs-darwin else nixpkgs-linux) {
            inherit (machine) system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = { inherit machine inputs; };
          modules = [ ./hosts/${host}/home.nix ];
        };
      mkMac = overrides:
        let machine = machines.mac // overrides;
        in nix-darwin.lib.darwinSystem {
          specialArgs = { inherit machine; };
          modules = [
            ./hosts/mac
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = false;
              home-manager.extraSpecialArgs = { inherit machine inputs; };
              home-manager.users.${machine.username} = import ./hosts/mac/home.nix;
            }
          ];
        };
    in {
      lib = { inherit mkHome mkMac; };
      homeConfigurations = {
        mac = mkHome "mac" { };
        homelab = mkHome "homelab" { };
      };
      darwinConfigurations.mac = mkMac { };
    };
}
