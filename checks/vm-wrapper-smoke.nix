{ pkgs
, hostSystem
, gondolinLib
, gondolinPackage
}:
let
  guestAssets = gondolinLib.mkGondolinGuestAssets {
    inherit hostSystem;
  };

  vmWrapper = gondolinLib.mkGondolinVM {
    inherit hostSystem guestAssets gondolinPackage;
    name = "gondolin-vm-wrapper-smoke";
  };
in
pkgs.runCommand "gondolin-vm-wrapper-smoke"
{
  nativeBuildInputs = [
    pkgs.gnugrep
    vmWrapper
  ];
} ''
  set -euo pipefail

  export HOME="$TMPDIR"

  gondolin-vm-wrapper-smoke exec -- /bin/true

  smoke_output="$(gondolin-vm-wrapper-smoke exec -- /bin/sh -lc 'echo __GONDOLIN_VM_WRAPPER_SMOKE_OK__')"
  printf '%s\n' "$smoke_output" | grep -q "__GONDOLIN_VM_WRAPPER_SMOKE_OK__"

  mkdir -p "$out"
''
