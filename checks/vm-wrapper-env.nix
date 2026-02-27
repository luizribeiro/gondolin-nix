{ pkgs
, hostSystem
, gondolinLib
, ...
}:
let
  fakeGondolin = pkgs.writeShellScriptBin "gondolin" ''
    set -euo pipefail

    {
      printf 'GONDOLIN_GUEST_DIR=%s\n' "''${GONDOLIN_GUEST_DIR-__UNSET__}"
      printf 'SIMPLE=%s\n' "''${SIMPLE-__UNSET__}"
      printf 'WITH_SPACE=%s\n' "''${WITH_SPACE-__UNSET__}"
      if [ "''${OMITTED+x}" = "x" ]; then
        printf 'OMITTED_SET=1\n'
      else
        printf 'OMITTED_SET=0\n'
      fi
    } > "''${GONDOLIN_ENV_CAPTURE:?}"

    printf '%s\n' "$@" > "''${GONDOLIN_ARGS_CAPTURE:?}"
  '';

  guestAssetsPath = "/tmp/gondolin-guest-assets";

  vmWrapper = gondolinLib.mkGondolinVM {
    inherit hostSystem;
    guestAssets = guestAssetsPath;
    gondolinPackage = fakeGondolin;
    name = "gondolin-vm-wrapper-env";

    env = {
      SIMPLE = "value";
      WITH_SPACE = "hello world";
      OMITTED = null;
    };
  };
in
pkgs.runCommand "gondolin-vm-wrapper-env"
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

  unset OMITTED
  gondolin-vm-wrapper-env list --help

  printf '%s\n' \
    "GONDOLIN_GUEST_DIR=${guestAssetsPath}" \
    "SIMPLE=value" \
    "WITH_SPACE=hello world" \
    "OMITTED_SET=0" \
    > "$TMPDIR/expected-env.txt"

  printf '%s\n' \
    "list" \
    "--help" \
    > "$TMPDIR/expected-args.txt"

  cmp "$TMPDIR/expected-env.txt" "$GONDOLIN_ENV_CAPTURE"
  cmp "$TMPDIR/expected-args.txt" "$GONDOLIN_ARGS_CAPTURE"

  mkdir -p "$out"
''
