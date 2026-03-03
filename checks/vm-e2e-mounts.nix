{ pkgs
, hostSystem
, gondolinLib
, gondolinPackage
}:
let
  guestAssets = gondolinLib.mkGondolinGuestAssets {
    inherit hostSystem;
  };

  hostRwPath = "/tmp/gondolin-e2e-mounts-rw";
  hostRoPath = "/tmp/gondolin-e2e-mounts-ro";

  vmWrapper = gondolinLib.mkGondolinVM {
    inherit hostSystem guestAssets gondolinPackage;
    name = "gondolin-vm-e2e-mounts";

    vm.mounts = [
      {
        hostPath = hostRwPath;
        guestPath = "/mnt/rw";
      }
      {
        hostPath = hostRoPath;
        guestPath = "/mnt/ro";
        readOnly = true;
      }
    ];
  };
in
pkgs.runCommand "gondolin-vm-e2e-mounts"
{
  nativeBuildInputs = [
    pkgs.coreutils
    pkgs.gnugrep
    vmWrapper
  ];
} ''
  set -euo pipefail

  export HOME="$TMPDIR"

  rm -rf ${hostRwPath} ${hostRoPath}
  mkdir -p ${hostRwPath} ${hostRoPath}

  printf '%s\n' "from-host" > ${hostRwPath}/in.txt
  printf '%s\n' "read-only-host-dir" > ${hostRoPath}/seed.txt

  mount_probe='\
    set -euo pipefail; \
    [ "$(cat /mnt/rw/in.txt)" = "from-host" ]; \
    printf "%s\\n" "from-guest" > /mnt/rw/out.txt; \
    if /bin/sh -lc "printf \"%s\\n\" \"should-fail\" > /mnt/ro/deny.txt" 2>/dev/null; then \
      echo "unexpectedly wrote to read-only mount" >&2; \
      exit 1; \
    fi; \
    echo __GONDOLIN_VM_E2E_MOUNTS_OK__\
  '

  mount_output="$(gondolin-vm-e2e-mounts exec -- /bin/sh -lc "$mount_probe")"
  printf '%s\n' "$mount_output" | grep -q "__GONDOLIN_VM_E2E_MOUNTS_OK__"

  [ "$(cat ${hostRwPath}/out.txt)" = "from-guest" ]
  [ ! -e ${hostRoPath}/deny.txt ]

  mkdir -p "$out"
''
