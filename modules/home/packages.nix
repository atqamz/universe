{
  pkgs,
  lib,
  inputs,
  ...
}:
let
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
        --set __VK_LAYER_NV_optimus NVIDIA_only

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
      zed-editor
      (writeShellScriptBin "zed" ''exec ${zed-editor}/bin/zeditor "$@"'')
      brave
      unityhub
      unzip
      inputs.claude-code.packages.${pkgs.system}.default
      inputs.codex-cli.packages.${pkgs.system}.default
      bibata-cursors
      jq
      bun
      (writeShellScriptBin "npx" ''exec ${bun}/bin/bunx "$@"'')
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
    ]
  );
}
