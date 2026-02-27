# simple-vm template

This template shows the minimal public API composition to run a VM:

- `gondolin-nix.lib.mkGondolinGuestAssets`
- `gondolin-nix.lib.mkGondolinVM`

`mkGondolinVM` wraps the Gondolin CLI, exports `GONDOLIN_GUEST_DIR`, and keeps passthrough access to other subcommands.

## Usage

```bash
nix run
# or: nix run .
```

## Notes

- The template uses `github:luizribeiro/gondolin-nix` by default.
- For local development, point `inputs.gondolin-nix.url` to a local path.
