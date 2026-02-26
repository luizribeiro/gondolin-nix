{ lib, config, pkgs, ... }:

let
  cfg = config.virtualisation.gondolin.guest;

  initramfsLib = import ./initramfs {
    inherit lib pkgs;
  };

  rootfsLib = import ./rootfs.nix {
    inherit lib pkgs;
  };

  manifestLib = import ./manifest.nix {
    inherit lib pkgs;
  };

  guestArch =
    if pkgs.stdenv.hostPlatform.isAarch64 then
      "aarch64"
    else
      "x86_64";
in
lib.mkIf cfg.enable {
  system.build.gondolinAssets = manifestLib.mkGuestAssetsManifest {
    arch = guestArch;
    inherit
      (cfg)
      rootfsLabel
      diskSizeMb
      ;
    kernelPath = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
    initramfsPath = initramfsLib.mkGuestInitramfs {
      inherit (config.system) modulesTree;
    };
    rootfsPath = rootfsLib.mkGuestRootfs {
      inherit config;
      rootfsLabel = cfg.rootfsLabel;
      diskSizeMb = cfg.diskSizeMb;
    };
  };
}
