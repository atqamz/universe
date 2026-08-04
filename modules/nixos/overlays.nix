_: {
  nixpkgs.overlays = [
    (
      final: prev:
      import ../../pkgs {
        inherit (prev) lib;
        inherit (final) callPackage;
      }
    )
  ];
}
