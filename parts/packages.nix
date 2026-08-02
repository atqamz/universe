_: {
  perSystem =
    { pkgs, ... }:
    {
      packages = import ../pkgs { inherit (pkgs) lib callPackage; };
    };
}
