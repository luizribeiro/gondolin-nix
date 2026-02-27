{ pkgs
, hostSystem
, gondolinLib
, ...
}:
let
  expectEvalFailure = label: expr:
    let
      result = builtins.tryEval (builtins.deepSeq expr expr);
    in
    if result.success then
      throw "vm-wrapper-validation: expected evaluation failure for ${label}"
    else
      true;

  _unknownOption = expectEvalFailure "unknown option key" (
    gondolinLib.mkGondolinVM {
      inherit hostSystem;
      guestAssets = "/tmp/gondolin-guest-assets";
      unknownOption = true;
    }
  );

  _relativeMountGuestPath = expectEvalFailure "non-absolute vm.mounts.guestPath" (
    gondolinLib.mkGondolinVM {
      inherit hostSystem;
      guestAssets = "/tmp/gondolin-guest-assets";
      vm.mounts = [
        {
          hostPath = "/host";
          guestPath = "relative/path";
        }
      ];
    }
  );

  _invalidExtraFlagsType = expectEvalFailure "invalid extraFlags type" (
    gondolinLib.mkGondolinVM {
      inherit hostSystem;
      guestAssets = "/tmp/gondolin-guest-assets";
      extraFlags = "--allow-host";
    }
  );

  _invalidEnvValueType = expectEvalFailure "invalid env value type" (
    gondolinLib.mkGondolinVM {
      inherit hostSystem;
      guestAssets = "/tmp/gondolin-guest-assets";
      env.BAD_VALUE = 123;
    }
  );

  _invalidEnvKeyName = expectEvalFailure "invalid env key name" (
    gondolinLib.mkGondolinVM {
      inherit hostSystem;
      guestAssets = "/tmp/gondolin-guest-assets";
      env."BAD-KEY" = "value";
    }
  );

  _invalidGondolinPackageType = expectEvalFailure "invalid gondolinPackage type" (
    gondolinLib.mkGondolinVM {
      inherit hostSystem;
      guestAssets = "/tmp/gondolin-guest-assets";
      gondolinPackage = "not-a-derivation";
    }
  );

  _nonCoercibleGuestAssets = expectEvalFailure "non-coercible guestAssets" (
    gondolinLib.mkGondolinVM {
      inherit hostSystem;
      guestAssets = {
        __toString = _: throw "uncoercible guestAssets";
      };
    }
  );

  _nonStringHostSystem = expectEvalFailure "non-string hostSystem" (
    gondolinLib.mkGondolinVM {
      hostSystem = 42;
      guestAssets = "/tmp/gondolin-guest-assets";
    }
  );

  _unsupportedHostSystem = expectEvalFailure "unsupported hostSystem" (
    gondolinLib.mkGondolinVM {
      hostSystem = "mips-linux";
      guestAssets = "/tmp/gondolin-guest-assets";
    }
  );

  checks = [
    _unknownOption
    _relativeMountGuestPath
    _invalidExtraFlagsType
    _invalidEnvValueType
    _invalidEnvKeyName
    _invalidGondolinPackageType
    _nonCoercibleGuestAssets
    _nonStringHostSystem
    _unsupportedHostSystem
  ];
in
builtins.deepSeq checks (pkgs.runCommand "gondolin-vm-wrapper-validation" { } ''
  set -euo pipefail

  mkdir -p "$out"
'')
