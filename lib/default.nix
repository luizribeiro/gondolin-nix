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
    , specialArgs ? { }
    , modulesLocation ? null
    }:
    let
      gondolinPackages = import nixpkgs {
        system = guestSystem;
        overlays = [ overlay ];
      };
    in
    nixosSystem (
      {
        system = guestSystem;
        specialArgs = specialArgs // { inherit gondolinPackages; };
        modules = [
          guestModule
          ({ ... }: {
            virtualisation.gondolin.guest.enable = true;
          })
        ] ++ modules;
      }
      // lib.optionalAttrs (modulesLocation != null) {
        inherit modulesLocation;
      }
    );

  resolveGondolinPackage =
    { hostSystem
    , gondolinPackage
    }:
    if gondolinPackage != null then
      if lib.isDerivation gondolinPackage then
        gondolinPackage
      else
        throw "mkGondolinVM.gondolinPackage must be a derivation when provided"
    else
      (import nixpkgs {
        system = hostSystem;
        overlays = [ overlay ];
      }).gondolin;

  mkGondolinVMConfig = rawArgs:
    let
      types = lib.types;
      evalResult = lib.evalModules {
        modules = [
          ({ ... }: {
            options = {
              name = lib.mkOption {
                type = types.str;
                default = "gondolin-vm";
                apply = value:
                  if value != "" then
                    value
                  else
                    throw "mkGondolinVM.name must be a non-empty string";
              };

              env = lib.mkOption {
                type = types.attrsOf (types.nullOr types.str);
                default = { };
                apply = value:
                  let
                    badKeys = builtins.filter
                      (key: builtins.match "^[A-Za-z_][A-Za-z0-9_]*$" key == null)
                      (builtins.attrNames value);
                  in
                  if badKeys == [ ] then
                    value
                  else
                    throw "mkGondolinVM.env.${builtins.head badKeys}: invalid env var name; expected shell identifier";
              };

              vm = {
                mounts = lib.mkOption {
                  type = types.listOf (types.submodule ({ ... }: {
                    options = {
                      hostPath = lib.mkOption {
                        type = types.str;
                        apply = value:
                          if value != "" then
                            value
                          else
                            throw "mkGondolinVM.vm.mounts.<entry>.hostPath must be a non-empty string";
                      };

                      guestPath = lib.mkOption {
                        type = types.str;
                        apply = value:
                          if lib.hasPrefix "/" value then
                            value
                          else
                            throw "mkGondolinVM.vm.mounts.<entry>.guestPath must be an absolute path";
                      };

                      readOnly = lib.mkOption {
                        type = types.bool;
                        default = false;
                      };
                    };
                  }));
                  default = [ ];
                };

                memfs = lib.mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  apply = values:
                    map
                      (value:
                        if lib.hasPrefix "/" value then
                          value
                        else
                          throw "mkGondolinVM.vm.memfs entries must be absolute paths"
                      )
                      values;
                };

                network = {
                  allowHttpHosts = lib.mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    apply = values:
                      map
                        (value:
                          if value != "" then
                            value
                          else
                            throw "mkGondolinVM.vm.network.allowHttpHosts entries must be non-empty strings"
                        )
                        values;
                  };

                  disableWebSockets = lib.mkOption {
                    type = types.bool;
                    default = false;
                  };
                };
              };

              extraFlags = lib.mkOption {
                type = types.listOf types.str;
                default = [ ];
              };
            };

            config = rawArgs;
          })
        ];
      };
    in
    {
      inherit (evalResult.config) name env vm extraFlags;
    };

  renderVmFlags = vm:
    let
      mountFlags = lib.concatMap
        (mount: [
          "--mount-hostfs"
          "${mount.hostPath}:${mount.guestPath}${lib.optionalString mount.readOnly ":ro"}"
        ])
        vm.mounts;

      memfsFlags = lib.concatMap (path: [ "--mount-memfs" path ]) vm.memfs;
      allowHostFlags = lib.concatMap (host: [ "--allow-host" host ]) vm.network.allowHttpHosts;
      wsFlags = lib.optional vm.network.disableWebSockets "--disable-websockets";
    in
    mountFlags ++ memfsFlags ++ allowHostFlags ++ wsFlags;

  renderEnvExports = env:
    lib.concatMapStrings
      (name:
        let
          value = env.${name};
        in
        lib.optionalString (value != null) "export ${name}=${lib.escapeShellArg value}\n"
      )
      (builtins.attrNames env);

  renderShellArray = name: values:
    "${name}=(${lib.concatMapStringsSep " " lib.escapeShellArg values})";
in
{
  mkGondolinGuestAssets =
    { hostSystem
    , modules ? [ ]
    , specialArgs ? { }
    , modulesLocation ? null
    }:
    let
      guestSystem = linuxGuestSystemForHost hostSystem;
      guestConfiguration = mkGondolinGuestSystem {
        inherit
          guestSystem
          modules
          specialArgs
          modulesLocation
          ;
      };
    in
    guestConfiguration.config.system.build.gondolinAssets;

  mkGondolinVM =
    args@{ hostSystem
    , guestAssets
    , name ? "gondolin-vm"
    , gondolinPackage ? null
    , env ? { }
    , vm ? { }
    , extraFlags ? [ ]
    , ...
    }:
      assert builtins.isString hostSystem
        || throw "mkGondolinVM.hostSystem must be a string";
      assert lib.hasPrefix "aarch64" hostSystem || lib.hasPrefix "x86_64" hostSystem
        || throw "mkGondolinVM.hostSystem: unsupported hostSystem '${hostSystem}'. Supported prefixes: aarch64, x86_64";
      let
        guestAssetsPath =
          if guestAssets == null then
            throw "mkGondolinVM.guestAssets is required and cannot be null"
          else
            let
              coerced = builtins.tryEval (toString guestAssets);
            in
            if coerced.success then
              coerced.value
            else
              throw "mkGondolinVM.guestAssets must be coercible to a path/string";

        vmConfig = mkGondolinVMConfig (builtins.removeAttrs args [ "hostSystem" "guestAssets" "gondolinPackage" ]);

        selectedGondolinPackage = resolveGondolinPackage {
          inherit hostSystem gondolinPackage;
        };

        vmFlags = renderVmFlags vmConfig.vm;
        exportedEnv = renderEnvExports vmConfig.env;
      in
      (import nixpkgs {
        system = hostSystem;
        overlays = [ overlay ];
      }).writeShellScriptBin vmConfig.name ''
        set -euo pipefail

        export GONDOLIN_GUEST_DIR=${lib.escapeShellArg guestAssetsPath}
        ${exportedEnv}

        GONDOLIN_BIN=${lib.escapeShellArg "${selectedGondolinPackage}/bin/gondolin"}
        if [ ! -x "$GONDOLIN_BIN" ]; then
          echo "mkGondolinVM: expected executable at $GONDOLIN_BIN" >&2
          exit 1
        fi

        subcommand="''${1-}"
        if [ -n "$subcommand" ]; then
          shift
        fi

        ${renderShellArray "vm_defaults" vmFlags}
        ${renderShellArray "extra_flags" vmConfig.extraFlags}

        case "$subcommand" in
          bash|exec)
            exec "$GONDOLIN_BIN" "$subcommand" "''${vm_defaults[@]}" "''${extra_flags[@]}" "$@"
            ;;
          "")
            exec "$GONDOLIN_BIN"
            ;;
          *)
            exec "$GONDOLIN_BIN" "$subcommand" "$@"
            ;;
        esac
      '';
}
