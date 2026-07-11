{ pkgs, ... }:
let
  ctSettings = {
    Appearance = {
      style = "adwaita-dark";
      icon_theme = "Papirus-Dark";
      standard_dialogs = "xdgdesktopportal";
    };
  };
in
{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style = {
      name = "adwaita-dark";
      package = [
        pkgs.adwaita-qt
        pkgs.adwaita-qt6
      ];
    };
    qt5ctSettings = ctSettings;
    qt6ctSettings = ctSettings;
  };
}
