{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  dotnetSdk = pkgs.dotnet-sdk_10;

  primeEnv = {
    __NV_PRIME_RENDER_OFFLOAD = "1";
    __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __VK_LAYER_NV_optimus = "NVIDIA_only";
  };
  primeExports = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${v}") primeEnv);
  primeWrapperArgs = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "--set ${k} ${v}") primeEnv);

  occtVersion = "17.0.3";

  zed = pkgs.symlinkJoin {
    name = "zed";
    paths = [ pkgs.zed-editor ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/zeditor
      makeWrapper ${pkgs.zed-editor}/bin/zeditor $out/bin/zeditor \
        --set DOTNET_ROOT ${dotnetSdk.unwrapped}/share/dotnet \
        --prefix PATH : ${lib.makeBinPath [ pkgs.nil ]}
      ln -s zeditor $out/bin/zed
    '';
  };

  nodeShim = pkgs.writeShellScriptBin "node" ''exec ${pkgs.bun}/bin/bun "$@"'';

  npxShim = pkgs.writeShellScriptBin "npx" ''exec ${pkgs.bun}/bin/bunx "$@"'';

  claude = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;

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
        ${primeWrapperArgs} \
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
    ${primeExports}
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
      ${primeExports}
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
      bun
      nodeShim
      npxShim
      claude
      (pkgs.opencode.overrideAttrs (_: {
        installPhase =
          builtins.replaceStrings [ "--set OPENCODE_DISABLE_AUTOUPDATE true" ] [ "" ]
            pkgs.opencode.installPhase;
      }))
      inputs.treehouse.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.mirufm.packages.${pkgs.stdenv.hostPlatform.system}.default
      rtk
      codedb
      no-mistakes
      bibata-cursors
      jq
      age
      sops
      gh
      firebase-tools
      google-cloud-sdk
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
      bitwarden-cli
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
