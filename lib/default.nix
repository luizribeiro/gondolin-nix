{ lib
, nixosSystem
, agentix
}:
let
  guestModule = import ../modules/guest;

  linuxGuestSystemForHost = hostSystem:
    if lib.hasPrefix "aarch64" hostSystem then
      "aarch64-linux"
    else
      "x86_64-linux";

  mkGondolinGuestSystem =
    { guestSystem
    , modules ? [ ]
    }:
    let
      gondolinPackages = agentix.packages.${guestSystem};
    in
    nixosSystem {
      system = guestSystem;
      specialArgs = { inherit gondolinPackages; };
      modules = [
        guestModule
        ({ ... }: {
          virtualisation.gondolin.guest.enable = true;
        })
      ] ++ modules;
    };
in
{
  mkGondolinGuestAssets =
    { hostSystem
    , modules ? [ ]
    }:
    let
      guestSystem = linuxGuestSystemForHost hostSystem;
      guestConfiguration = mkGondolinGuestSystem {
        inherit guestSystem modules;
      };
    in
    guestConfiguration.config.system.build.gondolinAssets;
}
