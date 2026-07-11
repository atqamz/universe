{ pkgs, lib, ... }:
let
  targets = {
    fuzzel = {
      description = "fuzzel.ini";
      render = ''
        out="$HOME/.config/fuzzel"
        mkdir -p "$out"
        jq -r '"# Generated from caelestia scheme.json by fuzzel-theme-sync. Do not edit;\n# overwritten on the next scheme change.\n[main]\nfont=sans-serif:size=13\nlines=8\nwidth=35\nhorizontal-pad=20\nvertical-pad=16\ninner-pad=8\n\n[border]\nwidth=2\nradius=18\n\n[colors]\nbackground=\(.colours.surfaceContainer)ff\ntext=\(.colours.onSurface)ff\nprompt=\(.colours.onSurfaceVariant)ff\ninput=\(.colours.onSurface)ff\nplaceholder=\(.colours.outline)ff\nmatch=\(.colours.primary)ff\nselection=\(.colours.primaryContainer)ff\nselection-text=\(.colours.onPrimaryContainer)ff\nselection-match=\(.colours.primary)ff\ncounter=\(.colours.outline)ff\nborder=\(.colours.primary)ff"' "$scheme" > "$out/fuzzel.ini.tmp"
        mv "$out/fuzzel.ini.tmp" "$out/fuzzel.ini"
      '';
    };
    gtk = {
      description = "GTK css";
      render = ''
        mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
        write() {
          jq -r "$1" "$scheme" > "$2.tmp" && mv "$2.tmp" "$2"
        }
        write '"@define-color theme_bg_color #\(.colours.background);\n@define-color theme_fg_color #\(.colours.onBackground);\n@define-color theme_base_color #\(.colours.surfaceContainer);\n@define-color theme_text_color #\(.colours.onSurface);\n@define-color theme_selected_bg_color #\(.colours.primary);\n@define-color theme_selected_fg_color #\(.colours.onPrimary);\n@define-color insensitive_bg_color #\(.colours.background);\n@define-color insensitive_fg_color #\(.colours.outline);\n@define-color borders #\(.colours.outline);\n@define-color theme_unfocused_bg_color #\(.colours.background);\n@define-color theme_unfocused_fg_color #\(.colours.onBackground);\n"' "$HOME/.config/gtk-3.0/gtk.css"
        write '"@define-color window_bg_color #\(.colours.background);\n@define-color window_fg_color #\(.colours.onBackground);\n@define-color view_bg_color #\(.colours.surfaceContainer);\n@define-color view_fg_color #\(.colours.onSurface);\n@define-color headerbar_bg_color #\(.colours.surfaceContainer);\n@define-color headerbar_fg_color #\(.colours.onSurface);\n@define-color sidebar_bg_color #\(.colours.surfaceContainer);\n@define-color sidebar_fg_color #\(.colours.onSurface);\n@define-color card_bg_color #\(.colours.surfaceContainer);\n@define-color popover_bg_color #\(.colours.surfaceContainer);\n@define-color dialog_bg_color #\(.colours.surfaceContainer);\n@define-color accent_bg_color #\(.colours.primary);\n@define-color accent_fg_color #\(.colours.onPrimary);\n@define-color accent_color #\(.colours.primary);\n@define-color destructive_bg_color #\(.colours.error);\n@define-color destructive_fg_color #\(.colours.onError);\n"' "$HOME/.config/gtk-4.0/gtk.css"
      '';
    };
  };

  mkScript =
    name: t:
    pkgs.writeShellApplication {
      name = "${name}-theme-sync";
      runtimeInputs = with pkgs; [
        jq
        coreutils
      ];
      text = ''
        scheme="$HOME/.local/state/caelestia/scheme.json"
        [ -f "$scheme" ] || exit 0
        ${t.render}
      '';
    };
in
{
  systemd.user.services = lib.mapAttrs' (
    name: t:
    lib.nameValuePair "${name}-theme-sync" {
      Unit.Description = "Render ${t.description} from the caelestia scheme";
      Service = {
        Type = "oneshot";
        ExecStart = "${mkScript name t}/bin/${name}-theme-sync";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    }
  ) targets;

  systemd.user.paths = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "${name}-theme-sync" {
      Unit.Description = "Watch the caelestia scheme for ${name} re-theming";
      Path.PathChanged = "%h/.local/state/caelestia/scheme.json";
      Install.WantedBy = [ "graphical-session.target" ];
    }
  ) targets;
}
