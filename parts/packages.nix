{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = package: inputs.nixpkgs.lib.getName package == "unity-cli";
      };
    in
    {
      packages = import ../pkgs { inherit (pkgs) lib callPackage; };
    };
}
