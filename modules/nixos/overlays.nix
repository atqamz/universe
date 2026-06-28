_: {
  nixpkgs.overlays = [
    (final: _prev: {
      codedb = final.callPackage ../../pkgs/codedb { };
      no-mistakes = final.callPackage ../../pkgs/no-mistakes { };
    })
  ];
}
