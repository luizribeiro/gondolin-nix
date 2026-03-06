{
  description = "Simple Gondolin VM consumer template";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    gondolin-nix.url = "github:luizribeiro/gondolin-nix";
    gondolin-nix.inputs.nixpkgs.follows = "nixpkgs";
    gondolin-nix.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { nixpkgs, flake-utils, gondolin-nix, ... }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ] (hostSystem:
      let
        guestAssets = gondolin-nix.lib.mkGondolinGuestAssets {
          inherit hostSystem;
          modules = [
            ({ pkgs, ... }: {
              environment.systemPackages = with pkgs; [
                bashInteractive
                curl
                git
                jq
              ];
            })
          ];
        };

        gondolinPackage = gondolin-nix.packages.${hostSystem}.gondolin;

        vmWrapper = gondolin-nix.lib.mkGondolinVM {
          inherit hostSystem guestAssets gondolinPackage;
          name = "gondolin-template-vm";
        };
      in
      {
        apps.default = {
          type = "app";
          program = "${vmWrapper}/bin/gondolin-template-vm";
        };
      });
}
