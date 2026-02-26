final: prev:
{
  gondolin = final.callPackage ../packages/gondolin { };
}
// prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  gondolin-guest-bins = final.callPackage ../packages/gondolin-guest-bins { };
}
