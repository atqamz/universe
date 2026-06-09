_: {
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        shellHook = config.pre-commit.installationScript;
        packages = [
          config.treefmt.build.wrapper
          pkgs.statix
          pkgs.deadnix
        ];
      };
    };
}
