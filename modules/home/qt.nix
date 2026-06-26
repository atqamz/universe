{
  pkgs,
  ...
}:
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
    qt5ctSettings = {
      Appearance = {
        style = "adwaita-dark";
        icon_theme = "Papirus-Dark";
        standard_dialogs = "xdgdesktopportal";
      };
    };
    qt6ctSettings = {
      Appearance = {
        style = "adwaita-dark";
        icon_theme = "Papirus-Dark";
        standard_dialogs = "xdgdesktopportal";
      };
    };
  };
}
