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

  vm-special-args = import ./special-args.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };

  vm-wrapper-smoke = import ./vm-wrapper-smoke.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };
}
