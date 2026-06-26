{ pkgs, ... }:
let
  themeSync = pkgs.writeShellApplication {
    name = "gtk-theme-sync";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = ''
      scheme="$HOME/.local/state/caelestia/scheme.json"
      [ -f "$scheme" ] || exit 0

      mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

      write() {
        jq -r "$1" "$scheme" > "$2.tmp" && mv "$2.tmp" "$2"
      }

      write '"@define-color theme_bg_color #\(.colours.background);\n@define-color theme_fg_color #\(.colours.onBackground);\n@define-color theme_base_color #\(.colours.surfaceContainer);\n@define-color theme_text_color #\(.colours.onSurface);\n@define-color theme_selected_bg_color #\(.colours.primary);\n@define-color theme_selected_fg_color #\(.colours.onPrimary);\n@define-color insensitive_bg_color #\(.colours.background);\n@define-color insensitive_fg_color #\(.colours.outline);\n@define-color borders #\(.colours.outline);\n@define-color theme_unfocused_bg_color #\(.colours.background);\n@define-color theme_unfocused_fg_color #\(.colours.onBackground);\n"' "$HOME/.config/gtk-3.0/gtk.css"

      write '"@define-color window_bg_color #\(.colours.background);\n@define-color window_fg_color #\(.colours.onBackground);\n@define-color view_bg_color #\(.colours.surfaceContainer);\n@define-color view_fg_color #\(.colours.onSurface);\n@define-color headerbar_bg_color #\(.colours.surfaceContainer);\n@define-color headerbar_fg_color #\(.colours.onSurface);\n@define-color sidebar_bg_color #\(.colours.surfaceContainer);\n@define-color sidebar_fg_color #\(.colours.onSurface);\n@define-color card_bg_color #\(.colours.surfaceContainer);\n@define-color popover_bg_color #\(.colours.surfaceContainer);\n@define-color dialog_bg_color #\(.colours.surfaceContainer);\n@define-color accent_bg_color #\(.colours.primary);\n@define-color accent_fg_color #\(.colours.onPrimary);\n@define-color accent_color #\(.colours.primary);\n@define-color destructive_bg_color #\(.colours.error);\n@define-color destructive_fg_color #\(.colours.onError);\n"' "$HOME/.config/gtk-4.0/gtk.css"
    '';
  };
in
{
  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  systemd.user.services.gtk-theme-sync = {
    Unit.Description = "Render GTK css from the caelestia scheme";
    Service = {
      Type = "oneshot";
      ExecStart = "${themeSync}/bin/gtk-theme-sync";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.paths.gtk-theme-sync = {
    Unit.Description = "Watch the caelestia scheme for GTK re-theming";
    Path.PathChanged = "%h/.local/state/caelestia/scheme.json";
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
