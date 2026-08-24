{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      final: prev:
      import ../../pkgs {
        inherit (prev) lib;
        inherit (final) callPackage;
      }
      // {
        treehouse =
          inputs.treehouse.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs
            (old: {
              nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [ final.python3 ];
              postPatch = (old.postPatch or "") + ''
                substituteInPlace .github/scripts/no-mistakes-gate.sh \
                  --replace-fail '#!/usr/bin/env bash' '#!${final.bash}/bin/bash'
                substituteInPlace no_mistakes_gate_test.go \
                  --replace-fail '#!/usr/bin/env bash' '#!${final.bash}/bin/bash'
              '';
            });
      }
    )
  ];
}
