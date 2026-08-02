{ pkgs, lib, ... }:
let
  prime = import ../../lib/prime.nix { inherit lib; };

  occtVersion = "17.0.3";

  gpuLibPath =
    "/run/opengl-driver/lib:/run/opengl-driver-32/lib:"
    + lib.makeLibraryPath (
      with pkgs;
      [
        stdenv.cc.cc.lib
        vulkan-loader
        libGL
        libGLU
        fontconfig.lib
        freetype
        zlib
        openssl
        icu
        libxkbcommon
        wayland
        libx11
        libxext
        libxrender
        libxrandr
        libxfixes
        libxcursor
        libxi
        libxcb
        libice
        libsm
      ]
    );

  occtBin = pkgs.runCommand "occt-${occtVersion}" { } ''
    install -Dm755 ${
      pkgs.fetchurl {
        name = "occt-${occtVersion}";
        url = "https://www.ocbase.com/download/edition:Personal/version:${occtVersion}/os:Linux";
        hash = "sha256-ouXU9Qr11dltWmEATlJyG30odWbGjwtwHBBxe4DxFh4=";
      }
    } $out/bin/OCCT
  '';

  occt = pkgs.writeShellScriptBin "occt" ''
    ${prime.exports}
    export VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json
    export PATH=${
      lib.makeBinPath [
        pkgs.zfs
        pkgs.rocmPackages.rocm-smi
      ]
    }:$PATH
    export LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.rocmPackages.rocm-smi ]}:${gpuLibPath}
    dir="''${XDG_DATA_HOME:-$HOME/.local/share}/occt"
    mkdir -p "$dir"
    if [ "$(cat "$dir/.version" 2>/dev/null)" != "${occtVersion}" ]; then
      install -m755 ${occtBin}/bin/OCCT "$dir/OCCT"
      echo ${occtVersion} > "$dir/.version"
    fi
    cd "$dir"
    exec ./OCCT "$@"
  '';

  furmarkApp = pkgs.stdenv.mkDerivation {
    pname = "furmark-app";
    version = "2.10.2";
    src = pkgs.fetchurl {
      url = "https://gpumagick.com/downloads/files/2025/fm2/2_10_dbc69dd0a08da5ff09169a4fc759ddaa/FurMark_2.10.2_linux64.7z";
      hash = "sha256-s9AEj9r7kBhPGPU365HgxS9tEyrm7UjLtoxD21pCrts=";
    };
    nativeBuildInputs = [ pkgs.p7zip ];
    unpackPhase = "7z x $src";
    installPhase = ''
      mkdir -p $out
      cp -r FurMark_linux64/. $out/
    '';
  };

  mkFurmark =
    name: exe:
    pkgs.writeShellScriptBin name ''
      ${prime.exports}
      export VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json
      if [ -n "''${DISPLAY:-}" ] && [ -z "$(${pkgs.xrdb}/bin/xrdb -query 2>/dev/null)" ]; then
        echo "Xft.dpi: 96" | ${pkgs.xrdb}/bin/xrdb -merge 2>/dev/null || true
      fi
      dir="''${XDG_DATA_HOME:-$HOME/.local/share}/furmark"
      mkdir -p "$dir"
      cp -rn --preserve=mode ${furmarkApp}/. "$dir"/
      chmod -R u+w "$dir"
      export LD_LIBRARY_PATH="$dir/dylibs":${gpuLibPath}
      cd "$dir"
      exec ./${exe} "$@"
    '';
in
{
  home.packages = [
    occt
    (mkFurmark "furmark" "furmark")
    (mkFurmark "furmark-gui" "FurMark_GUI")
  ];

  xdg.desktopEntries = {
    occt = {
      name = "OCCT";
      genericName = "GPU and CPU stress test";
      exec = "occt";
      terminal = false;
      categories = [
        "System"
        "Utility"
      ];
    };
    furmark = {
      name = "FurMark";
      genericName = "GPU stress test";
      exec = "furmark-gui";
      terminal = false;
      categories = [
        "System"
        "Utility"
      ];
    };
  };
}
