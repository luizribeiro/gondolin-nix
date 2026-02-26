# gondolin-nix

Minimal Nix flake for building [Gondolin](https://github.com/earendil-works/gondolin/) guest assets from NixOS and running them.

## Run Gondolin directly (no install, default Alpine guest)

If you just want a quick Gondolin CLI run without installing anything:

```bash
nix run github:luizribeiro/gondolin-nix#gondolin -- bash
# or
nix run github:luizribeiro/gondolin-nix#gondolin -- exec -- /bin/true
```

This uses Gondolin's default behavior (Alpine guest assets), without custom NixOS guest configuration.
For custom NixOS guests and reproducible assets, use the template/direct flows below.

## Template usage

```bash
mkdir my-gondolin-vm && cd my-gondolin-vm
nix flake init -t github:luizribeiro/gondolin-nix#simple-vm
```

Interactive shell:

```bash
nix run -- bash
```

Other Gondolin subcommands work too, for example:

```bash
nix run -- exec -- /bin/true
nix run -- exec -- /bin/sh -lc 'echo hello from vm'
```

## Direct usage (without template)

Use `mkGondolinGuestAssets` and `packages.<system>.gondolin` directly in your own flake, including your own guest NixOS customizations:

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

        guestAssets = gondolin-nix.lib.mkGondolinGuestAssets {
          hostSystem = system;
          modules = [
            ({ pkgs, ... }: {
              networking.hostName = "devbox";
              time.timeZone = "UTC";

              environment.systemPackages = with pkgs; [
                bashInteractive
                curl
                git
                jq
                ripgrep
                neovim
              ];

              environment.variables.EDITOR = "nvim";
            })
          ];
        };

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

Run it:

```bash
nix run -- bash
# or
nix run -- exec -- /bin/sh -lc 'uname -a && git --version && nvim --version | head -n1'
```

## Public API (stability contract)

The following outputs are the supported, stable API surface of this flake.
We avoid breaking changes to these APIs.

- `lib.mkGondolinGuestAssets`
- `packages.<system>.gondolin`
- `templates.simple-vm`

### `packages.<system>.gondolin`

Gondolin host CLI package for the target system. This is what you execute to run subcommands like:

- `gondolin bash`
- `gondolin exec -- ...`

In downstream flakes, this is typically wrapped with `GONDOLIN_GUEST_DIR` set to your generated guest assets.

### `templates.simple-vm`

A minimal starter flake that demonstrates end-to-end usage of the stable API:

- builds assets with `lib.mkGondolinGuestAssets`
- runs VM commands with `packages.<system>.gondolin`

Bootstrap with:

```bash
nix flake init -t github:luizribeiro/gondolin-nix#simple-vm
```

### `lib.mkGondolinGuestAssets`

```nix
mkGondolinGuestAssets {
  hostSystem = <string>;
  modules = [ ... ]; # optional
}
```

Arguments:

- `hostSystem` (required, string)
  - Host platform where assets are built, typically `system` from `eachSystem`.
  - Supported values today:
    - `aarch64-darwin`
    - `aarch64-linux`
    - `x86_64-linux`
  - This is mapped internally to the Linux guest architecture (`aarch64-linux` or `x86_64-linux`).

- `modules` (optional, list of NixOS modules, default `[]`)
  - Extra NixOS modules merged into the guest configuration.
  - Use this to customize packages, environment variables, hostname, timezone, and other guest settings.

Returns:

- A derivation path to a Gondolin guest asset directory containing:
  - `manifest.json`
  - `vmlinuz-virt`
  - `initramfs.cpio.lz4`
  - `rootfs.ext4`
