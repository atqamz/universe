{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  dotnetSdk = pkgs.dotnet-sdk_10;

  zedTools = with pkgs; [
    nil
    go
    gopls
    rust-analyzer
    pyright
    typescript-language-server
  ];

  zed = pkgs.symlinkJoin {
    name = "zed";
    paths = [ pkgs.zed-editor ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/zeditor
      makeWrapper ${pkgs.zed-editor}/bin/zeditor $out/bin/zeditor \
        --set DOTNET_ROOT ${dotnetSdk.unwrapped}/share/dotnet \
        --prefix PATH : ${lib.makeBinPath zedTools}
      ln -s zeditor $out/bin/zed
    '';
  };

  nodeShim = pkgs.writeShellScriptBin "node" ''exec ${pkgs.bun}/bin/bun "$@"'';

  npxShim = pkgs.writeShellScriptBin "npx" ''exec ${pkgs.bun}/bin/bunx "$@"'';

  claude = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
      rtk
      codedb
      no-mistakes
      tasks-axi
      gh-axi
      lavish-axi
      chrome-devtools-axi
      quota-axi
      qmd
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
      libreoffice
      tmux
      neovim
      handy
      starship
      direnv
      zoxide
      eza
      lazygit
      podman-tui
    ]
  );
}
