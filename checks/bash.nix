{ pkgs
, system
, gondolinLib
, gondolinPackage
}:
let
  guestAssets = gondolinLib.mkGondolinGuestAssets {
    hostSystem = system;
  };
in
pkgs.runCommand "gondolin-vm-bash"
  {
    nativeBuildInputs = [
      gondolinPackage
      pkgs.gnugrep
    ];
  } ''
  set -euo pipefail

  export HOME="$TMPDIR"
  export GONDOLIN_GUEST_DIR="${guestAssets}"

  bash_output="$(gondolin bash -- /bin/sh -lc 'echo __GONDOLIN_BASH_OK__')"
  printf '%s\n' "$bash_output" | grep -q "__GONDOLIN_BASH_OK__"

  mkdir -p "$out"
''
