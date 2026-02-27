{ pkgs
, hostSystem
, gondolinLib
, gondolinPackage
}:
let
  templateFlake = import ../templates/simple-vm/flake.nix;

  flakeUtilsMock = {
    lib.eachSystem = systems: f:
      builtins.listToAttrs (map
        (system: {
          name = system;
          value = f system;
        })
        systems);
  };

  fakeGondolinPackage = pkgs.writeShellScriptBin "gondolin" ''
    printf 'FAKE_GONDOLIN_ARGS:%s\n' "$*"
    printf 'FAKE_GUEST_DIR:%s\n' "''${GONDOLIN_GUEST_DIR-}"
  '';

  templateOutputs = templateFlake.outputs {
    nixpkgs = pkgs.path;
    flake-utils = flakeUtilsMock;
    gondolin-nix = {
      lib = gondolinLib;
      packages.${hostSystem}.gondolin = fakeGondolinPackage;
    };
  };

  defaultProgram = templateOutputs.${hostSystem}.apps.default.program;
in
pkgs.runCommand "template-simple-vm"
{
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  set -euo pipefail

  [ -x "${defaultProgram}" ]

  passthrough_output="$("${defaultProgram}" list --help)"

  printf '%s\n' "$passthrough_output" | grep -q '^FAKE_GONDOLIN_ARGS:list --help$'
  printf '%s\n' "$passthrough_output" | grep -Eq '^FAKE_GUEST_DIR:.+$'

  grep -q "mkGondolinVM" ${../templates/simple-vm/README.md}

  mkdir -p "$out"
''
