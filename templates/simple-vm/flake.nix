{
  description = "Simple Gondolin VM consumer template";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # If you are developing locally, change this to:
    # gondolin-nix.url = "path:/absolute/path/to/gondolin-nix";
    gondolin-nix.url = "github:luizribeiro/gondolin-nix";
    gondolin-nix.inputs.nixpkgs.follows = "nixpkgs";
    gondolin-nix.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { nixpkgs, flake-utils, gondolin-nix, ... }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ] (hostSystem:
      let
        pkgs = import nixpkgs { system = hostSystem; };

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

        gondolinBin = pkgs.writeShellScriptBin "gondolin-template-vm" ''
          export GONDOLIN_GUEST_DIR=${guestAssets}
          exec ${gondolin-nix.packages.${hostSystem}.gondolin}/bin/gondolin "$@"
        '';
      in
      {
        apps.default = {
          type = "app";
          program = "${gondolinBin}/bin/gondolin-template-vm";
        };
      });
}
