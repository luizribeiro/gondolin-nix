{ pkgs
, hostSystem
, gondolinLib
, ...
}:
let
  fakeGondolin = pkgs.writeShellScriptBin "gondolin" ''
    set -euo pipefail
    printf '%s\n' "$@"
  '';

  vmWrapper = gondolinLib.mkGondolinVM {
    inherit hostSystem;
    guestAssets = "/tmp/gondolin-guest-assets";
    gondolinPackage = fakeGondolin;
    name = "gondolin-vm-wrapper-passthrough";

    vm = {
      mounts = [
        {
          hostPath = "/host/share";
          guestPath = "/guest/share";
        }
      ];
      memfs = [ "/tmp/memfs" ];
      network.allowHttpHosts = [ "example.test" ];
    };
  };
in
pkgs.runCommand "gondolin-vm-wrapper-passthrough"
{
  nativeBuildInputs = [
    pkgs.coreutils
    vmWrapper
  ];
} ''
  set -euo pipefail

  export HOME="$TMPDIR"

  gondolin-vm-wrapper-passthrough list --help > "$TMPDIR/list.args"
  gondolin-vm-wrapper-passthrough build --help > "$TMPDIR/build.args"
  gondolin-vm-wrapper-passthrough snapshot --help > "$TMPDIR/snapshot.args"

  printf '%s\n' \
    "list" \
    "--help" \
    > "$TMPDIR/expected-list.args"

  printf '%s\n' \
    "build" \
    "--help" \
    > "$TMPDIR/expected-build.args"

  printf '%s\n' \
    "snapshot" \
    "--help" \
    > "$TMPDIR/expected-snapshot.args"

  cmp "$TMPDIR/expected-list.args" "$TMPDIR/list.args"
  cmp "$TMPDIR/expected-build.args" "$TMPDIR/build.args"
  cmp "$TMPDIR/expected-snapshot.args" "$TMPDIR/snapshot.args"

  mkdir -p "$out"
''
