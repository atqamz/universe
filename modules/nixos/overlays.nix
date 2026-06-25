_: {
  nixpkgs.overlays = [
    (final: _prev: {
      codedb = final.callPackage ../../pkgs/codedb { };
    })
  ];
}
