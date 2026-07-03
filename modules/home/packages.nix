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
      tmux
      neovim
      handy
    ]
  );
}
