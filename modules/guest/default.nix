{ lib, config, pkgs, gondolinPackages ? null, ... }:

let
  cfg = config.virtualisation.gondolin.guest;
in
{
  imports = [
    ./assets
    ./sandbox-stack.nix
  ];

  options.virtualisation.gondolin.guest = {
    enable = lib.mkEnableOption "Gondolin guest profile";

    rootfsLabel = lib.mkOption {
      type = lib.types.str;
      default = "gondolin-root";
      description = "Root filesystem label for the Gondolin guest image.";
    };

    diskSizeMb = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Optional fixed rootfs size in MiB.";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/" = {
      device = lib.mkDefault "/dev/disk/by-label/${cfg.rootfsLabel}";
      fsType = lib.mkDefault "ext4";
    };

    boot.loader.grub.devices = lib.mkDefault [ "/dev/vda" ];
    system.stateVersion = lib.mkDefault "25.11";

    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "virtualisation.gondolin.guest is currently supported on Linux only.";
      }
      {
        assertion = gondolinPackages != null && builtins.hasAttr "gondolin-guest-bins" gondolinPackages;
        message = "virtualisation.gondolin.guest requires specialArgs.gondolinPackages.\"gondolin-guest-bins\"";
      }
    ];
  };
}
