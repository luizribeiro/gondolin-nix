{
  description = "gondolin-nix: minimal Nix flake for building and running Gondolin VM assets";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    agentix = {
      url = "github:luizribeiro/agentix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { nixpkgs, flake-utils, agentix, ... }:
    let
      gondolinLib = import ./lib {
        lib = nixpkgs.lib;
        nixosSystem = nixpkgs.lib.nixosSystem;
        inherit agentix;
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
        pkgs = import nixpkgs { inherit system; };
        gondolinPackage = agentix.packages.${system}.gondolin;
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
      });
}
