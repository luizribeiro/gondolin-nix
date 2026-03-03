{ pkgs
, hostSystem
, gondolinLib
, gondolinPackage
}:
let
  guestAssets = gondolinLib.mkGondolinGuestAssets {
    inherit hostSystem;
  };

  memfsPath = "/tmp/gondolin-e2e-memfs";

  vmWrapper = gondolinLib.mkGondolinVM {
    inherit hostSystem guestAssets gondolinPackage;
    name = "gondolin-vm-e2e-memfs";

    vm.memfs = [ memfsPath ];
  };
in
pkgs.runCommand "gondolin-vm-e2e-memfs"
{
  nativeBuildInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.gnugrep
    vmWrapper
  ];
} ''
  set -euo pipefail

  export HOME="$TMPDIR"

  memfs_probe='\
    set -euo pipefail; \
    awk "\$2 == \"${memfsPath}\" { found = 1 } END { exit(found ? 0 : 1) }" /proc/mounts; \
    printf "%s\\n" "memfs-data" > ${memfsPath}/probe.txt; \
    [ "$(cat ${memfsPath}/probe.txt)" = "memfs-data" ]; \
    echo __GONDOLIN_VM_E2E_MEMFS_OK__\
  '

  memfs_output="$(gondolin-vm-e2e-memfs exec -- /bin/sh -lc "$memfs_probe")"
  printf '%s\n' "$memfs_output" | grep -q "__GONDOLIN_VM_E2E_MEMFS_OK__"

  mkdir -p "$out"
''
