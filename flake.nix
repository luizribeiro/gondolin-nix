{
  description = "gondolin-nix: minimal Nix flake for building and running Gondolin VM assets";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    let
      overlay = import ./lib/overlay.nix;
      mkPkgsForSystem = system: import nixpkgs {
        inherit system;
        overlays = [ overlay ];
      };

      gondolinLib = import ./lib {
        lib = nixpkgs.lib;
        nixosSystem = nixpkgs.lib.nixosSystem;
        inherit mkPkgsForSystem;
      };

      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
    in
    {
      lib = {
        inherit (gondolinLib) mkGondolinGuestAssets;
      };

      templates.simple-vm = {
        path = ./templates/simple-vm;
        description = "Minimal consumer flake that runs Gondolin via gondolin-nix public APIs";
      };
    }
    // flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = mkPkgsForSystem system;
        gondolinPackage = pkgs.gondolin;
      in
      {
        packages = {
          gondolin = gondolinPackage;
        };

        checks = import ./checks {
          inherit
            pkgs
            system
            gondolinLib
            gondolinPackage
            ;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            jq
            nushell
            nixpkgs-fmt
          ];

          shellHook = ''
            echo "gondolin-nix dev shell"
            echo "- run checks: nix flake check"
            echo "- format nix: nixpkgs-fmt ."
            echo "- update gondolin: nu scripts/update-package.nu gondolin"
          '';
        };
      });
}
