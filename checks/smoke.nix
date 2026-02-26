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
pkgs.runCommand "gondolin-vm-smoke"
{
  nativeBuildInputs = [
    gondolinPackage
    pkgs.coreutils
    pkgs.jq
    pkgs.gnugrep
  ];
} ''
  set -euo pipefail

  export HOME="$TMPDIR"
  export GONDOLIN_GUEST_DIR="${guestAssets}"

  manifest="$GONDOLIN_GUEST_DIR/manifest.json"

  # Basic guest assets shape assertions
  [ -d "$GONDOLIN_GUEST_DIR" ]
  [ -f "$manifest" ]
  [ -L "$GONDOLIN_GUEST_DIR/vmlinuz-virt" ]
  [ -L "$GONDOLIN_GUEST_DIR/initramfs.cpio.lz4" ]
  [ -L "$GONDOLIN_GUEST_DIR/rootfs.ext4" ]

  # Manifest schema assertions (current minimum upstream-aligned shape)
  jq -e '
    .version == 1 and
    (.buildTime | type == "string") and
    (.config.arch == "aarch64" or .config.arch == "x86_64") and
    (.config.distro == "nixos") and
    (.config.rootfs.label | type == "string") and
    (.assets.kernel == "vmlinuz-virt") and
    (.assets.initramfs == "initramfs.cpio.lz4") and
    (.assets.rootfs == "rootfs.ext4") and
    (.checksums.kernel | type == "string") and
    (.checksums.initramfs | type == "string") and
    (.checksums.rootfs | type == "string")
  ' "$manifest" >/dev/null

  checksum_file() {
    local file="$1"
    sha256sum "$file" | cut -d ' ' -f1
  }

  kernel_checksum="$(checksum_file "$GONDOLIN_GUEST_DIR/vmlinuz-virt")"
  initramfs_checksum="$(checksum_file "$GONDOLIN_GUEST_DIR/initramfs.cpio.lz4")"
  rootfs_checksum="$(checksum_file "$GONDOLIN_GUEST_DIR/rootfs.ext4")"

  # Checksum assertions against manifest
  [ "$kernel_checksum" = "$(jq -r '.checksums.kernel' "$manifest")" ]
  [ "$initramfs_checksum" = "$(jq -r '.checksums.initramfs' "$manifest")" ]
  [ "$rootfs_checksum" = "$(jq -r '.checksums.rootfs' "$manifest")" ]

  # Runtime smoke assertions
  gondolin exec -- /bin/true

  smoke_output="$(gondolin exec -- /bin/sh -lc 'echo __GONDOLIN_VM_SMOKE_OK__')"
  printf '%s\n' "$smoke_output" | grep -q "__GONDOLIN_VM_SMOKE_OK__"

  mkdir -p "$out"
''
