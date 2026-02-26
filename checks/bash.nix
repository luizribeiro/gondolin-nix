{ pkgs
, system
, gondolinLib
, gondolinPackage
}:
let
  guestAssets = gondolinLib.mkGondolinGuestAssets {
    hostSystem = system;
  };
in
pkgs.runCommand "gondolin-vm-bash"
{
  nativeBuildInputs = [
    gondolinPackage
    pkgs.expect
  ];
} ''
  set -euo pipefail

  export HOME="$TMPDIR"
  export GONDOLIN_GUEST_DIR="${guestAssets}"

  expect <<'EOF'
    set timeout 30
    set marker "__GONDOLIN_BASH_IO_OK:42__"

    spawn gondolin bash

    # Wait for the interactive prompt before sending command.
    set ready 0
    for {set i 0} {$i < 15} {incr i} {
      send -- "\r"
      expect {
        -re {root@nixos:/\]# ?} {
          set ready 1
          break
        }
        timeout {}
      }
    }

    if {!$ready} {
      send_user "timed out waiting for interactive prompt\n"
      exit 1
    }

    send -- "printf '__GONDOLIN_BASH_IO_OK:%s__\\n' \"\$(expr 40 + 2)\"\r"

    # The typed command contains '%s', not ':42', so matching this marker
    # confirms command execution/output (not just terminal input echo).
    expect {
      -re "$marker" {}
      timeout {
        send_user "timed out waiting for interactive command output\n"
        exit 1
      }
    }

    send -- "exit\r"
    expect eof
  EOF

  mkdir -p "$out"
''
