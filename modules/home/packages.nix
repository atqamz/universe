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
      # librsvg: SVG pixbuf loader for GTK dialog icons; shared-mime-info: mime
      # DB those dialogs query. Without these the Editor.log spams "no working
      # python interpreter" and Gtk pixbuf/mime warnings.
      (unityhub.override {
        extraPkgs =
          pkgs: with pkgs; [
            python3
            shared-mime-info
          ];
        extraLibs = pkgs: with pkgs; [ librsvg ];
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
