{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-termfilechooser
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [ "hyprland" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
  };
}
