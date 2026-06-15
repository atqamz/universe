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
      python3
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
