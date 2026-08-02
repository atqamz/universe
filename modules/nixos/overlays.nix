_: {
  nixpkgs.overlays = [
    (
      final: prev:
      {
        rtk = prev.rtk.overrideAttrs (old: {
          env = (old.env or { }) // {
            RUSTFLAGS = "--cap-lints warn";
          };
        });
      }
      // import ../../pkgs {
        inherit (prev) lib;
        inherit (final) callPackage;
      }
    )
  ];
}
