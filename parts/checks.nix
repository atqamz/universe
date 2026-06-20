{ self, ... }:
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

      checks = {
        toplevel-pavg15 = self.nixosConfigurations.pavg15.config.system.build.toplevel;
        toplevel-pavg15-minimal = self.nixosConfigurations.pavg15-minimal.config.system.build.toplevel;
      };
    };
}
