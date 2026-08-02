{ self, lib, ... }:
{
  perSystem =
    { config, ... }:
    {
      pre-commit.settings.hooks = {
        statix.enable = true;
        deadnix.enable = true;
        treefmt = {
          enable = true;
          packageOverrides.treefmt = config.treefmt.build.wrapper;
        };
      };

      checks = lib.mapAttrs' (
        name: host: lib.nameValuePair "toplevel-${name}" host.config.system.build.toplevel
      ) self.nixosConfigurations;
    };
}
