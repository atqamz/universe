{ pkgs, ... }:
{
  # Without an icon theme, GTK apps (file choosers, pavucontrol, nautilus-style
  # folder views) render the magenta/black "missing icon" checkerboard for
  # folders and mimetypes. Install Papirus and select it; gtk.enable writes
  # gtk-3.0/settings.ini + gsettings so GTK3/4 apps pick it up under Hyprland
  # (no DE to set it). caelestia handles the Qt/shell theming, not GTK icons.
  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };
}
