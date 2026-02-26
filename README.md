# gondolin-nix

Minimal Nix flake for building [Gondolin](https://github.com/earendil-works/gondolin/) guest assets from NixOS and running them.

## Public API

- `lib.mkGondolinGuestAssets`
- `packages.<system>.gondolin`
- `templates.simple-vm`

## Template usage

```bash
mkdir my-gondolin-vm && cd my-gondolin-vm
nix flake init -t github:luizribeiro/gondolin-nix#simple-vm
nix run -- exec -- /bin/true
```

## Direct usage (without template)

Use `mkGondolinGuestAssets` and `packages.<system>.gondolin` directly in your own flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gondolin-nix.url = "github:luizribeiro/gondolin-nix";
  };

  outputs = { nixpkgs, flake-utils, gondolin-nix, ... }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        guestAssets = gondolin-nix.lib.mkGondolinGuestAssets { hostSystem = system; };
        gondolinBin = pkgs.writeShellScriptBin "gondolin-vm" ''
          export GONDOLIN_GUEST_DIR=${guestAssets}
          exec ${gondolin-nix.packages.${system}.gondolin}/bin/gondolin "$@"
        '';
      in {
        apps.default = {
          type = "app";
          program = "${gondolinBin}/bin/gondolin-vm";
        };
      });
}
```

Then run:

```bash
nix run -- exec -- /bin/true
```
