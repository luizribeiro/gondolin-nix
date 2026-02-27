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
    name = "gondolin-vm-wrapper-flags";

    vm = {
      mounts = [
        {
          hostPath = "/host/share";
          guestPath = "/guest/share";
          readOnly = true;
        }
      ];
      memfs = [ "/tmp/memfs" ];
      network = {
        allowHttpHosts = [ "example.test" ];
        disableWebSockets = true;
      };
    };
  };
in
pkgs.runCommand "gondolin-vm-wrapper-flags"
{
  nativeBuildInputs = [
    pkgs.coreutils
    vmWrapper
  ];
} ''
  set -euo pipefail

  export HOME="$TMPDIR"
  export GONDOLIN_CAPTURE="$TMPDIR/args.txt"

  gondolin-vm-wrapper-flags exec -- /bin/true

  printf '%s\n' \
    "exec" \
    "--mount-hostfs" \
    "/host/share:/guest/share:ro" \
    "--mount-memfs" \
    "/tmp/memfs" \
    "--allow-host" \
    "example.test" \
    "--disable-websockets" \
    "--" \
    "/bin/true" \
    > "$TMPDIR/expected.txt"

  cmp "$TMPDIR/expected.txt" "$GONDOLIN_CAPTURE"

  mkdir -p "$out"
''
