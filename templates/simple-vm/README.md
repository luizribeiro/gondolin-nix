# simple-vm template

This template shows the minimal public API composition to run a VM:

- `gondolin-nix.lib.mkGondolinGuestAssets`
- `gondolin-nix.packages.<system>.gondolin`

## Usage

```bash
nix run
# or: nix run .
```

## Notes

- The template uses `github:luizribeiro/gondolin-nix` by default.
- For local development, point `inputs.gondolin-nix.url` to a local path.
