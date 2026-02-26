{ lib, pkgs }:

{
  mkGuestAssetsManifest =
    { arch
    , rootfsLabel
    , diskSizeMb ? null
    , kernelPath
    , initramfsPath
    , rootfsPath
    }:
    let
      manifestConfigJson = builtins.toJSON {
        inherit arch;
        distro = "nixos";
        rootfs =
          { label = rootfsLabel; }
          // lib.optionalAttrs (diskSizeMb != null) { sizeMb = diskSizeMb; };
      };
    in
    pkgs.runCommand "gondolin-assets" { } ''
      set -euo pipefail

      checksum_file() {
        local file="$1"
        ${pkgs.coreutils}/bin/sha256sum "$file" | ${pkgs.coreutils}/bin/cut -d ' ' -f1
      }

      mkdir -p "$out"

      ln -s "${kernelPath}" "$out/vmlinuz-virt"
      ln -s "${initramfsPath}" "$out/initramfs.cpio.lz4"
      ln -s "${rootfsPath}" "$out/rootfs.ext4"

      kernel_checksum="$(checksum_file "$out/vmlinuz-virt")"
      initramfs_checksum="$(checksum_file "$out/initramfs.cpio.lz4")"
      rootfs_checksum="$(checksum_file "$out/rootfs.ext4")"

      source_date_epoch="''${SOURCE_DATE_EPOCH:-1}"
      build_time="$(${pkgs.coreutils}/bin/date -u -d "@$source_date_epoch" +%Y-%m-%dT%H:%M:%SZ)"

      # TODO(gondolin-nix): add optional support for buildId/runtimeDefaults/ociSource
      # and schema-backed validation in checks.
      ${pkgs.jq}/bin/jq -n \
        --arg kernel "vmlinuz-virt" \
        --arg initramfs "initramfs.cpio.lz4" \
        --arg rootfs "rootfs.ext4" \
        --arg kernelChecksum "$kernel_checksum" \
        --arg initramfsChecksum "$initramfs_checksum" \
        --arg rootfsChecksum "$rootfs_checksum" \
        --arg buildTime "$build_time" \
        --argjson config '${manifestConfigJson}' \
        '{
          version: 1,
          buildTime: $buildTime,
          config: $config,
          assets: {
            kernel: $kernel,
            initramfs: $initramfs,
            rootfs: $rootfs
          },
          checksums: {
            kernel: $kernelChecksum,
            initramfs: $initramfsChecksum,
            rootfs: $rootfsChecksum
          }
        }' > "$out/manifest.json"
    '';
}
