{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  # mkAfter keeps the original module-merge order, so the home-path
  # derivation hash stays byte-identical after this split.
  home.packages = lib.mkAfter (
    with pkgs;
    [
      alacritty
      sourcegit
      zed-editor
      # Unity Editor runs inside unityhub's buildFHSEnv sandbox, so its runtime
      # deps must live in the FHS env, not home.packages (which never reaches
      # it). python3: Editor's python-interpreter probe (USD/asset tooling);
      # shared-mime-info: mime DB the Editor's GTK file dialogs query. Without
      # these the Editor.log spams "no working python interpreter" and a Gtk
      # mime-database warning. (librsvg for the SVG pixbuf loader was tried but
      # dropped: extraLibs/multiPkgs silently discards it on i686, and even via
      # extraPkgs gdk-pixbuf needs its loaders.cache regenerated to register the
      # loader — buildFHSEnv exposes no hook for that. The remaining pixbuf
      # warning is a cosmetic GTK theme-icon probe with no functional impact.)
      (unityhub.override {
        extraPkgs =
          pkgs: with pkgs; [
            python3
            shared-mime-info
          ];
      })
      # Unity Hub shells out to `unzip` for type=ZIP module installs (Android
      # SDK/NDK Tools, OpenJDK); without it on PATH those installs fail.
      unzip
      inputs.zen-browser.packages.${pkgs.system}.default
      inputs.claude-code.packages.${pkgs.system}.default
      inputs.codex-cli.packages.${pkgs.system}.default
      bibata-cursors
      jq
      gh
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
