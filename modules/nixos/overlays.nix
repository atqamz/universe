_: {
  nixpkgs.overlays = [
    (final: prev: {
      rtk = prev.rtk.overrideAttrs (old: {
        env = (old.env or { }) // {
          RUSTFLAGS = "--cap-lints warn";
        };
      });
      codedb = final.callPackage ../../pkgs/codedb { };
      no-mistakes = final.callPackage ../../pkgs/no-mistakes { };
      tasks-axi = final.callPackage ../../pkgs/tasks-axi { };
      gh-axi = final.callPackage ../../pkgs/gh-axi { };
      lavish-axi = final.callPackage ../../pkgs/lavish-axi { };
      chrome-devtools-axi = final.callPackage ../../pkgs/chrome-devtools-axi { };
      quota-axi = final.callPackage ../../pkgs/quota-axi { };
      qmd = final.callPackage ../../pkgs/qmd { };
    })
  ];
}
