# Contributing

Thanks for contributing to `gondolin-nix`.

## Development setup

Use `direnv` to auto-load the dev shell when entering the repository:

```bash
# from repo root

direnv allow
```

The dev shell installs and manages git hooks via `cachix/git-hooks.nix`.
Hook definitions live in `flake.nix` under `pre-commit-check`.

## Common commands

```bash
# run all checks locally
nix flake check

# format nix files
nixpkgs-fmt .
```

## CI notes

GitHub-hosted `macos-14` runners do not provide an `aarch64-linux` Nix builder by default.
Some `gondolin-nix` checks (the `vm-*` checks) need Linux guest builds, so they cannot run there.

To keep CI honest to runner capabilities, the flake defines `checks.<system>.ci`:

- Linux: includes all checks.
- macOS: includes all non-`vm-*` checks.

CI builds `checks.<system>.ci` plus `packages.<system>.gondolin`.

If you have a macOS environment with a configured Linux remote builder, you can still run full local checks with:

```bash
nix flake check
```
