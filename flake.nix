{
  description = "gondolin-nix: minimal Nix flake for building and running Gondolin VM assets";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = { nixpkgs, flake-utils, git-hooks, ... }:
    let
      overlay = import ./lib/overlay.nix;

      gondolinLib = import ./lib {
        inherit nixpkgs overlay;
      };

      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      # TODO: run `nix flake check --all-systems` in CI once suitable builders
      # are available for every supported hostSystem.
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
    // flake-utils.lib.eachSystem supportedSystems (hostSystem:
      let
        pkgs = import nixpkgs {
          system = hostSystem;
          overlays = [ overlay ];
        };
        gondolinPackage = pkgs.gondolin;

        pre-commit-check = git-hooks.lib.${hostSystem}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
          };
        };
      in
      {
        packages = {
          gondolin = gondolinPackage;
        };

        checks =
          let
            baseChecks =
              (import ./checks {
                inherit
                  pkgs
                  hostSystem
                  gondolinLib
                  gondolinPackage
                  ;
              })
              // {
                pre-commit = pre-commit-check;
              };

            # checks.<system>.ci is the CI-oriented subset used by GitHub Actions.
            # Darwin runners on GitHub do not provide an aarch64-linux builder, so
            # vm-* checks (which build Linux guest assets) are excluded there.
            ciCheckNames =
              if pkgs.stdenv.hostPlatform.isDarwin then
                builtins.filter (name: builtins.match "vm-.*" name == null) (builtins.attrNames baseChecks)
              else
                builtins.attrNames baseChecks;
          in
          baseChecks
          // {
            ci = pkgs.linkFarm "gondolin-ci-checks" (
              builtins.map
                (name: {
                  inherit name;
                  path = baseChecks.${name};
                })
                ciCheckNames
            );
          };

        devShells.default = pkgs.mkShell {
          packages =
            pre-commit-check.enabledPackages
            ++ (with pkgs; [
              jq
              nushell
              nixpkgs-fmt
            ]);

          shellHook = ''
            ${pre-commit-check.shellHook}

            echo "gondolin-nix dev shell"
            echo "- pre-commit hooks managed by git-hooks.nix"
            echo "- run checks: nix flake check"
            echo "- format nix: nixpkgs-fmt ."
            echo "- update gondolin: nu scripts/update-package.nu gondolin"
          '';
        };
      });
}
