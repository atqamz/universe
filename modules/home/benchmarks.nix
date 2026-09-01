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

in
{
  home.packages = [ occt ];

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
  };
}
