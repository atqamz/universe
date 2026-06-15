{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # Unity Editor runs inside unityhub's buildFHSEnv sandbox, so its runtime
  # deps must live in the FHS env, not home.packages (which never reaches
  # it). python3: Editor's python-interpreter probe (USD/asset tooling);
  # shared-mime-info: mime DB the Editor's GTK file dialogs query. Without
  # these the Editor.log spams "no working python interpreter" and a Gtk
  # mime-database warning. (librsvg for the SVG pixbuf loader was tried but
  # dropped: extraLibs/multiPkgs silently discards it on i686, and even via
  # extraPkgs gdk-pixbuf needs its loaders.cache regenerated to register the
  # loader -- buildFHSEnv exposes no hook for that. The remaining pixbuf
  # warning is a cosmetic GTK theme-icon probe with no functional impact.)
  unityhubBase = pkgs.unityhub.override {
    extraPkgs =
      p: with p; [
        python3
        shared-mime-info
      ];
  };

  # pavg15 is a hybrid laptop (AMD Renoir iGPU + NVIDIA GTX 1650). The iGPU is
  # primary, so apps render on Mesa/radeonsi by default -- and Unity's Built-in
  # RP materials come out magenta on that GL path. Force the Hub, and every
  # Editor it spawns, onto the NVIDIA dGPU via PRIME render-offload env. The FHS
  # sandbox inherits the ambient env, so the vars reach the Editor process. The
  # .desktop Exec is an absolute store path (a PATH-shadowing wrapper would be
  # bypassed when launched from the app menu), so repoint it at the wrapper too.
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
  # mkAfter keeps the original module-merge order, so the home-path
  # derivation hash stays byte-identical after this split.
  home.packages = lib.mkAfter (
    with pkgs;
    [
      alacritty
      sourcegit
      zed-editor
      # NVIDIA-offload-wrapped Unity Hub; see the let block above.
      unityhub
      # Unity Hub shells out to `unzip` for type=ZIP module installs (Android
      # SDK/NDK Tools, OpenJDK); without it on PATH those installs fail.
      unzip
      inputs.zen-browser.packages.${pkgs.system}.default
      inputs.claude-code.packages.${pkgs.system}.default
      inputs.codex-cli.packages.${pkgs.system}.default
      bibata-cursors
      jq
      gh
      # git-lfs: the nsr game project stores textures as LFS objects. Without
      # the filter binary on PATH a checkout leaves them as pointer stubs, so
      # Unity can't import the PNGs (DefaultAsset) and materials render magenta.
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
