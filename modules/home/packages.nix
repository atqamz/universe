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
      zed-editor
      unityhub
      inputs.zen-browser.packages.${pkgs.system}.default
      bibata-cursors
      jq
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
