# gondolin-nix

[![Checks](https://github.com/luizribeiro/gondolin-nix/actions/workflows/check.yml/badge.svg)](https://github.com/luizribeiro/gondolin-nix/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

Minimal Nix flake for building [Gondolin](https://github.com/earendil-works/gondolin/) guest assets from NixOS and running them.

## Quickstart (60 seconds)

If you just want to run Gondolin without installing anything:

```bash
nix run github:luizribeiro/gondolin-nix#gondolin -- bash
# or
nix run github:luizribeiro/gondolin-nix#gondolin -- exec -- /bin/true
```

This uses Gondolin's default behavior (Alpine guest assets).

---

## Template usage (recommended)

Create a new project from the included template:

```bash
mkdir my-gondolin-vm && cd my-gondolin-vm
nix flake init -t github:luizribeiro/gondolin-nix#simple-vm
```

Run a shell in the VM:

```bash
nix run -- bash
```

Run other commands in the VM:

```bash
nix run -- exec -- /bin/true
nix run -- exec -- /bin/sh -lc 'echo hello from vm'
```

---

## Direct usage (no template)

Use `lib.mkGondolinGuestAssets` + `lib.mkGondolinVM` directly in your own flake.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gondolin-nix.url = "github:luizribeiro/gondolin-nix";
  };

  outputs = { nixpkgs, flake-utils, gondolin-nix, ... }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ] (hostSystem:
      let
        # 1) Build Linux guest assets (kernel/initramfs/rootfs + manifest)
        guestAssets = gondolin-nix.lib.mkGondolinGuestAssets {
          inherit hostSystem;
        };

        # 2) Build a wrapper app that exports GONDOLIN_GUEST_DIR
        gondolinVm = gondolin-nix.lib.mkGondolinVM {
          inherit hostSystem guestAssets;
          vm.memfs = [ "/tmp" ];
          extraFlags = [ "--dns" "1.1.1.1" ];
        };
      in {
        apps.default = {
          type = "app";
          program = "${gondolinVm}/bin/gondolin-vm";
        };
      });
}
```

Run it:

```bash
nix run -- bash
nix run -- exec -- /bin/sh -lc 'uname -a'
```

---

## Customize the guest (minimal example)

You can pass extra NixOS modules to `mkGondolinGuestAssets`.

```nix
guestAssets = gondolin-nix.lib.mkGondolinGuestAssets {
  inherit hostSystem;
  modules = [
    ({ pkgs, ... }: {
      networking.hostName = "devbox";
      time.timeZone = "UTC";
      environment.systemPackages = with pkgs; [ git jq neovim ];
      environment.variables.EDITOR = "nvim";
    })
  ];
};
```

Then, for example:

```bash
nix run -- exec -- /bin/sh -lc 'git --version && jq --version && nvim --version | head -n1'
```

---

## Mental model

- `lib.mkGondolinGuestAssets` builds Linux guest assets from NixOS config.
- `packages.<hostSystem>.gondolin` is the host Gondolin CLI binary.
- `lib.mkGondolinVM` builds a wrapper that sets `GONDOLIN_GUEST_DIR` for you.

---

## Public API (stability contract)

The following outputs are the supported, stable API surface of this flake:

- `lib.mkGondolinGuestAssets`
- `lib.mkGondolinVM`
- `packages.<hostSystem>.gondolin`
- `templates.simple-vm`

### `packages.<hostSystem>.gondolin`

Gondolin host CLI package for the target system.
Use it for commands like:

- `gondolin bash`
- `gondolin exec -- ...`

### `templates.simple-vm`

A minimal starter flake that demonstrates end-to-end usage of the stable API.

Bootstrap with:

```bash
nix flake init -t github:luizribeiro/gondolin-nix#simple-vm
```

### `lib.mkGondolinGuestAssets`

```nix
mkGondolinGuestAssets {
  hostSystem = <string>;
  modules = [ ... ]; # optional
  specialArgs = { ... }; # optional
  modulesLocation = <path>; # optional
}
```

Arguments:

- `hostSystem` (required, string)
  - Host platform where assets are built, typically `hostSystem` from `eachSystem`.
  - Supported values today:
    - `aarch64-darwin`
    - `aarch64-linux`
    - `x86_64-linux`
  - Internally mapped to Linux guest architecture (`aarch64-linux` or `x86_64-linux`).

- `modules` (optional, list of NixOS modules, default `[]`)
  - Extra NixOS modules merged into guest configuration.

- `specialArgs` (optional, attribute set, default `{}`)
  - Extra arguments passed to all modules (same behavior as `nixosSystem`).
  - `gondolinPackages` is always injected by `gondolin-nix`.

- `modulesLocation` (optional, path, default `null`)
  - Source location used in error messages for inline modules.

Returns:

- A derivation path to a Gondolin guest asset directory containing:
  - `manifest.json`
  - `vmlinuz-virt`
  - `initramfs.cpio.lz4`
  - `rootfs.ext4`

### `lib.mkGondolinVM`

```nix
mkGondolinVM {
  hostSystem = <string>;
  guestAssets = <path-or-derivation>;

  name = "gondolin-vm"; # optional
  gondolinPackage = null; # optional
  env = { }; # optional
  vm = { }; # optional
  extraFlags = [ ]; # optional
}
```

Builds a wrapper derivation (`writeShellScriptBin`). `name` controls the wrapper binary path (`/bin/<name>`).

The wrapper:

1. always exports `GONDOLIN_GUEST_DIR=${guestAssets}`
2. exports non-null values from `env`
3. dispatches subcommands as follows:
   - `bash` / `exec`: injects generated VM defaults + `extraFlags`
   - all others (`list`, `attach`, `snapshot`, `build`, etc.): transparent passthrough

`extraFlags` is an escape hatch for advanced Gondolin CLI options not typed by `vm` yet.

Minimal composition example:

```nix
let
  guestAssets = gondolin-nix.lib.mkGondolinGuestAssets {
    inherit hostSystem;
  };

  gondolinVm = gondolin-nix.lib.mkGondolinVM {
    inherit hostSystem guestAssets;
    vm = {
      memfs = [ "/tmp" ];
      network.allowHttpHosts = [ "example.com" ];
    };
  };
in {
  apps.default = {
    type = "app";
    program = "${gondolinVm}/bin/gondolin-vm";
  };
}
```

For contribution workflow and CI notes, see [CONTRIBUTING.md](./CONTRIBUTING.md).
