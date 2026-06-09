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
      nautilus
      zed-editor
      inputs.zen-browser.packages.${pkgs.system}.default
      bibata-cursors
      jq
      hyprpicker
      grim
      slurp
      wl-clipboard
      brightnessctl
      playerctl
      pavucontrol
    ]
  );
}
