_: {
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
    };
}
