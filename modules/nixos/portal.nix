{ pkgs, ... }:
{
  # Route the "Open/Save file" portal dialog to a terminal file chooser backed
  # by yazi. programs.hyprland already registers xdg-desktop-portal-hyprland for
  # screenshot/screencast; we keep that as the default and only override the
  # FileChooser interface. gtk portal stays for Settings/Appearance lookups.
  #
  # The backend's own config (which terminal to spawn + the yazi wrapper) is
  # user-level and lives in modules/home/file-management.nix.
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
