{ pkgs
, hostSystem
, gondolinLib
, ...
}:
let
  fakeGondolin = pkgs.writeShellScriptBin "gondolin" ''
    set -euo pipefail

    printf 'GONDOLIN_GUEST_DIR=%s\n' "''${GONDOLIN_GUEST_DIR-__UNSET__}" > "''${GONDOLIN_ENV_CAPTURE:?}"
    printf '%s\n' "$@" > "''${GONDOLIN_ARGS_CAPTURE:?}"
  '';

  guestAssetsPath = "/tmp/gondolin guest assets";

  vmWrapper = gondolinLib.mkGondolinVM {
    inherit hostSystem;
    guestAssets = guestAssetsPath;
    gondolinPackage = fakeGondolin;
    name = "gondolin-vm-wrapper-quoting";

    vm.mounts = [
      {
        hostPath = "/host path";
        guestPath = "/guest path";
        readOnly = true;
      }
    ];

    extraFlags = [
      "--extra-flag"
      "value with spaces"
    ];
  };
in
pkgs.runCommand "gondolin-vm-wrapper-quoting"
{
  nativeBuildInputs = [
    pkgs.coreutils
    vmWrapper
  ];
} ''
  set -euo pipefail

  export HOME="$TMPDIR"
  export GONDOLIN_ENV_CAPTURE="$TMPDIR/env.txt"
  export GONDOLIN_ARGS_CAPTURE="$TMPDIR/args.txt"

  gondolin-vm-wrapper-quoting exec -- /bin/echo "hello world"

  printf '%s\n' \
    "GONDOLIN_GUEST_DIR=${guestAssetsPath}" \
    > "$TMPDIR/expected-env.txt"

  printf '%s\n' \
    "exec" \
    "--mount-hostfs" \
    "/host path:/guest path:ro" \
    "--extra-flag" \
    "value with spaces" \
    "--" \
    "/bin/echo" \
    "hello world" \
    > "$TMPDIR/expected-args.txt"

  cmp "$TMPDIR/expected-env.txt" "$GONDOLIN_ENV_CAPTURE"
  cmp "$TMPDIR/expected-args.txt" "$GONDOLIN_ARGS_CAPTURE"

  mkdir -p "$out"
''
