{ pkgs
, hostSystem
, gondolinLib
, gondolinPackage
}:
let
  marker = "__GONDOLIN_SPECIAL_ARGS_OK__";

  guestAssets = gondolinLib.mkGondolinGuestAssets {
    inherit hostSystem;
    specialArgs = {
      inherit marker;
    };
    modules = [
      ({ marker, ... }: {
        environment.variables.GONDOLIN_SPECIAL_ARGS_MARKER = marker;
      })
    ];
  };
in
pkgs.runCommand "gondolin-vm-special-args"
{
  nativeBuildInputs = [
    gondolinPackage
    pkgs.coreutils
    pkgs.gnugrep
  ];
} ''
  set -euo pipefail

  export HOME="$TMPDIR"
  export GONDOLIN_GUEST_DIR="${guestAssets}"

  special_args_output="$(gondolin exec -- /bin/sh -lc 'echo "$GONDOLIN_SPECIAL_ARGS_MARKER"')"
  printf '%s\n' "$special_args_output" | grep -q "${marker}"

  mkdir -p "$out"
''
