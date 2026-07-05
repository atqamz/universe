{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  dotnetSdk = pkgs.dotnet-sdk_10;

  zed = pkgs.symlinkJoin {
    name = "zed";
    paths = [ pkgs.zed-editor ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/zeditor
      makeWrapper ${pkgs.zed-editor}/bin/zeditor $out/bin/zeditor \
        --set DOTNET_ROOT ${dotnetSdk.unwrapped}/share/dotnet
      ln -s zeditor $out/bin/zed
    '';
  };

  claudeNode = pkgs.writeShellScriptBin "node" ''exec ${pkgs.bun}/bin/bun "$@"'';

  claude = pkgs.symlinkJoin {
    name = "claude";
    paths = [ inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/claude
      makeWrapper ${
        inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
      }/bin/claude $out/bin/claude \
        --prefix PATH : ${
          lib.makeBinPath [
            claudeNode
            pkgs.bun
          ]
        }
    '';
  };

  unityhubBase = pkgs.unityhub.override {
    extraPkgs =
      p: with p; [
        python3
        shared-mime-info
      ];
  };

  unityhub = pkgs.symlinkJoin {
    name = "unityhub-offload";
    paths = [ unityhubBase ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/unityhub
      makeWrapper ${unityhubBase}/bin/unityhub $out/bin/unityhub \
        --set __NV_PRIME_RENDER_OFFLOAD 1 \
        --set __NV_PRIME_RENDER_OFFLOAD_PROVIDER NVIDIA-G0 \
        --set __GLX_VENDOR_LIBRARY_NAME nvidia \
        --set __VK_LAYER_NV_optimus NVIDIA_only \
        --prefix PATH : ${lib.makeBinPath [ pkgs.ffmpeg ]}

      desktop=$out/share/applications/unityhub.desktop
      if [ -e "$desktop" ]; then
        src=$(readlink -f "$desktop")
        rm -f "$desktop"
        substitute "$src" "$desktop" \
          --replace-fail "${unityhubBase}/opt/unityhub/unityhub" "$out/bin/unityhub"
      fi
    '';
  };

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

  occtBin = pkgs.runCommand "occt-17.0.3" { } ''
    install -Dm755 ${
      pkgs.fetchurl {
        name = "occt-17.0.3";
        url = "https://www.ocbase.com/download/edition:Personal/version:17.0.3/os:Linux";
        hash = "sha256-ouXU9Qr11dltWmEATlJyG30odWbGjwtwHBBxe4DxFh4=";
      }
    } $out/bin/OCCT
  '';

  occt = pkgs.writeShellScriptBin "occt" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
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
    if [ "$(cat "$dir/.version" 2>/dev/null)" != "17.0.3" ]; then
      install -m755 ${occtBin}/bin/OCCT "$dir/OCCT"
      echo 17.0.3 > "$dir/.version"
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
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      export VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json
      dir="''${XDG_DATA_HOME:-$HOME/.local/share}/furmark"
      mkdir -p "$dir"
      cp -rn --preserve=mode ${furmarkApp}/. "$dir"/
      chmod -R u+w "$dir"
      export LD_LIBRARY_PATH="$dir/dylibs":${gpuLibPath}
      cd "$dir"
      exec ./${exe} "$@"
    '';
  furmark = mkFurmark "furmark" "furmark";
  furmarkGui = mkFurmark "furmark-gui" "FurMark_GUI";
in
{
  home.packages = lib.mkAfter (
    with pkgs;
    [
      sourcegit
      (writeShellScriptBin "sourcegit" ''exec ${sourcegit}/bin/SourceGit "$@"'')
      zed
      (brave.override {
        commandLineArgs = "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations,PulseaudioLoopbackForScreenShare";
      })
      unityhub
      unzip
      p7zip
      unar
      claude
      (pkgs.opencode.overrideAttrs (_: {
        installPhase =
          builtins.replaceStrings [ "--set OPENCODE_DISABLE_AUTOUPDATE true" ] [ "" ]
            pkgs.opencode.installPhase;
      }))
      inputs.treehouse.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
      rtk
      codedb
      no-mistakes
      bibata-cursors
      jq
      age
      sops
      gh
      git-lfs
      hyprpicker
      grim
      slurp
      wl-clipboard
      cliphist
      fuzzel
      brightnessctl
      pavucontrol
      obs-studio
      vlc
      filezilla
      btop
      nvitop
      occt
      furmark
      furmarkGui
      tmux
      neovim
      handy
    ]
  );

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
