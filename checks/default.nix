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

  vm-e2e-mounts = import ./vm-e2e-mounts.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };

  vm-wrapper-flags = import ./vm-wrapper-flags.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };

  vm-wrapper-passthrough = import ./vm-wrapper-passthrough.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };

  vm-wrapper-precedence = import ./vm-wrapper-precedence.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };

  vm-wrapper-env = import ./vm-wrapper-env.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };

  vm-wrapper-quoting = import ./vm-wrapper-quoting.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };

  vm-wrapper-validation = import ./vm-wrapper-validation.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };

  template-simple-vm = import ./template-simple-vm.nix {
    inherit
      pkgs
      hostSystem
      gondolinLib
      gondolinPackage
      ;
  };
}
