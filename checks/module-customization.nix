{ pkgs
, hostSystem
, gondolinLib
, gondolinPackage
}:
let
  guestAssets = gondolinLib.mkGondolinGuestAssets {
    inherit hostSystem;
    modules = [
      ({ pkgs, ... }: {
        environment.systemPackages = with pkgs; [
          git
          jq
        ];
      })
    ];
  };
in
pkgs.runCommand "gondolin-vm-module-customization"
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

  customization_probe='\
    git --version >/dev/null && \
    jq --version >/dev/null && \
    echo __GONDOLIN_MODULE_CUSTOMIZATION_OK__\
  '

  customization_output="$(gondolin exec -- /bin/sh -lc "$customization_probe")"
  printf '%s\n' "$customization_output" | grep -q "__GONDOLIN_MODULE_CUSTOMIZATION_OK__"

  mkdir -p "$out"
''
