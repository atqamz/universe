_: {
  nixpkgs.overlays = [
    (final: _prev: {
      codedb = final.callPackage ../../pkgs/codedb { };
      no-mistakes = final.callPackage ../../pkgs/no-mistakes { };
      tasks-axi = final.callPackage ../../pkgs/tasks-axi { };
      gh-axi = final.callPackage ../../pkgs/gh-axi { };
      lavish-axi = final.callPackage ../../pkgs/lavish-axi { };
      chrome-devtools-axi = final.callPackage ../../pkgs/chrome-devtools-axi { };
      quota-axi = final.callPackage ../../pkgs/quota-axi { };
    })
  ];
}
