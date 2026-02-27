{ pkgs
, hostSystem
, gondolinLib
, ...
}:
let
  fakeGondolin = pkgs.writeShellScriptBin "gondolin" ''
    set -euo pipefail
    printf '%s\n' "$@" > "''${GONDOLIN_CAPTURE:?}"
  '';

  vmWrapper = gondolinLib.mkGondolinVM {
    inherit hostSystem;
    guestAssets = "/tmp/gondolin-guest-assets";
    gondolinPackage = fakeGondolin;
    name = "gondolin-vm-wrapper-precedence";

    vm = {
      mounts = [
        {
          hostPath = "/defaults/host";
          guestPath = "/defaults/guest";
        }
      ];
      network.allowHttpHosts = [ "default.test" ];
    };

    extraFlags = [
      "--allow-host"
      "extra.test"
      "--extra-marker"
    ];
  };
in
pkgs.runCommand "gondolin-vm-wrapper-precedence"
{
  nativeBuildInputs = [
    pkgs.coreutils
    vmWrapper
  ];
} ''
  set -euo pipefail

  export HOME="$TMPDIR"
  export GONDOLIN_CAPTURE="$TMPDIR/args.txt"

  gondolin-vm-wrapper-precedence exec --allow-host user.test -- /bin/echo ok

  printf '%s\n' \
    "exec" \
    "--mount-hostfs" \
    "/defaults/host:/defaults/guest" \
    "--allow-host" \
    "default.test" \
    "--allow-host" \
    "extra.test" \
    "--extra-marker" \
    "--allow-host" \
    "user.test" \
    "--" \
    "/bin/echo" \
    "ok" \
    > "$TMPDIR/expected.txt"

  cmp "$TMPDIR/expected.txt" "$GONDOLIN_CAPTURE"

  mkdir -p "$out"
''
