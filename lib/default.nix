{ nixpkgs
, overlay
}:
let
  inherit (nixpkgs) lib;
  nixosSystem = nixpkgs.lib.nixosSystem;

  guestModule = import ../modules/guest;

  linuxGuestSystemForHost = hostSystem:
    if lib.hasPrefix "aarch64" hostSystem then
      "aarch64-linux"
    else if lib.hasPrefix "x86_64" hostSystem then
      "x86_64-linux"
    else
      throw "mkGondolinGuestAssets: unsupported hostSystem '${hostSystem}'. Supported prefixes: aarch64, x86_64";

  mkGondolinGuestSystem =
    { guestSystem
    , modules ? [ ]
    }:
    let
      gondolinPackages = import nixpkgs {
        system = guestSystem;
        overlays = [ overlay ];
      };
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
