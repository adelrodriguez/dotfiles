{
  description = "Disposable Home Manager pilot for the Mac and Ubuntu server";

  inputs = {
    nixpkgs-linux.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-linux";
  };

  outputs = { home-manager, nixpkgs-linux, nixpkgs-darwin, ... }: {
    homeConfigurations = {
      server = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs-linux.legacyPackages.x86_64-linux;
        modules = [
          ./home.nix
          ({ pkgs, ... }: { home.packages = [ pkgs.bash pkgs.hello pkgs.jq ]; })
        ];
      };
      mac = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs-darwin.legacyPackages.aarch64-darwin;
        modules = [
          ./home.nix
          ({ pkgs, ... }: { home.packages = [ pkgs.bash pkgs.hello pkgs.jq ]; })
        ];
      };
    };
  };
}
