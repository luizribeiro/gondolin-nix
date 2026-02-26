{ pkgs
, hostSystem
, gondolinLib
, gondolinPackage
}:
{
  vm-smoke = import ./smoke.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };

  vm-bash = import ./bash.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };

  vm-module-customization = import ./module-customization.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };
}
