{ pkgs
, system
, gondolinLib
, gondolinPackage
}:
{
  vm-smoke = import ./smoke.nix {
    inherit
      pkgs
      system
      gondolinLib
      gondolinPackage
      ;
  };

  vm-bash = import ./bash.nix {
    inherit
      pkgs
      system
      gondolinLib
      gondolinPackage
      ;
  };
}
