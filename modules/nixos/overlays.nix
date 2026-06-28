_: {
  nixpkgs.overlays = [
    (final: prev: {
      codedb = final.callPackage ../../pkgs/codedb { };

      mimalloc2 = prev.mimalloc.overrideAttrs (_: rec {
        version = "2.2.7";
        src = final.fetchFromGitHub {
          owner = "microsoft";
          repo = "mimalloc";
          rev = "v${version}";
          hash = "sha256-z9qMOTcGkURblZChXDGfQ58hrql52lG6EE1NQmxxuj0=";
        };
      });

      ladybird = (prev.ladybird.override { mimalloc = final.mimalloc2; }).overrideAttrs (old: {
        version = "0-unstable-2026-06-28";
        buildInputs = old.buildInputs ++ [
          final.libedit
          final.cpptrace
          (final.runCommand "wuffs-0.3.4" {
            src = final.fetchFromGitHub {
              owner = "google";
              repo = "wuffs-mirror-release-c";
              rev = "v0.3.4";
              hash = "sha256-V7inWJqH7Q4Ac/ZB//7XHrpgfAYUPBxWBerBem6Q/Kk=";
            };
          } "install -D -m644 $src/release/c/wuffs-v0.3.c $out/include/wuffs/wuffs-v0.3.c")
        ];
        preConfigure = old.preConfigure + ''
          mkdir -p build/Caches/HSTSPreload
          cp ${
            final.fetchurl {
              url = "https://raw.githubusercontent.com/chromium/chromium/main/net/http/transport_security_state_static.json";
              hash = "sha256-YuiotSk0Lf3IHz/UjgCmU/brdB1lszob6DN4DXyjiWU=";
            }
          } build/Caches/HSTSPreload/transport_security_state_static.json
        '';
        src = final.fetchFromGitHub {
          owner = "LadybirdBrowser";
          repo = "ladybird";
          rev = "35ce19dcfb424e7be9b577f939ee02d93d22f85d";
          hash = "sha256-LIVF+1AEFO+TEYBiYVoMUug7sC0C4+dC9x+NnL4r66Q=";
        };
        cargoDeps = final.rustPlatform.fetchCargoVendor {
          src = final.fetchFromGitHub {
            owner = "LadybirdBrowser";
            repo = "ladybird";
            rev = "35ce19dcfb424e7be9b577f939ee02d93d22f85d";
            hash = "sha256-LIVF+1AEFO+TEYBiYVoMUug7sC0C4+dC9x+NnL4r66Q=";
          };
          hash = "sha256-HI2GQEOkI25h1uYLIlMGb1wedDQ3mH+o7m1I9AM4LvA=";
        };
      });
    })
  ];
}
