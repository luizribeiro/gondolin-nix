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
# run all checks (same high-level command used in CI)
nix flake check

# format nix files
nixpkgs-fmt .
```
