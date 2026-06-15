{ pkgs, ... }:
let
  # fuzzel is the only menu in this setup that isn't caelestia-native (passmenu
  # pipes through it). caelestia derives a Material-3 palette from the active
  # scheme and writes it to ~/.local/state/caelestia/scheme.json, rewriting it
  # whenever the scheme changes. We mirror that palette into fuzzel.ini so the
  # password picker matches the shell -- and re-render on every scheme change.
  #
  # fuzzel.ini is generated into a writable path (not home.file): a read-only
  # store symlink would block the re-render, same trap as caelestia's shell.json.
  themeSync = pkgs.writeShellApplication {
    name = "fuzzel-theme-sync";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = ''
      scheme="$HOME/.local/state/caelestia/scheme.json"
      out="$HOME/.config/fuzzel"
      [ -f "$scheme" ] || exit 0
      mkdir -p "$out"

      # Emit the whole fuzzel.ini in one jq pass. Mapping M3 roles to fuzzel keys:
      # surfaceContainer is the elevated menu body, primaryContainer carries the
      # selection so it reads as the same accent caelestia uses; every colour
      # gets a full-opacity alpha byte. Written to a tmp then moved so a reader
      # never sees a half-written file.
      tmp="$out/fuzzel.ini.tmp"
      jq -r '"# Generated from caelestia scheme.json by fuzzel-theme-sync. Do not edit;\n# overwritten on the next scheme change.\n[main]\nfont=sans-serif:size=13\nlines=8\nwidth=35\nhorizontal-pad=20\nvertical-pad=16\ninner-pad=8\n\n[border]\nwidth=2\nradius=18\n\n[colors]\nbackground=\(.colours.surfaceContainer)ff\ntext=\(.colours.onSurface)ff\nprompt=\(.colours.onSurfaceVariant)ff\ninput=\(.colours.onSurface)ff\nplaceholder=\(.colours.outline)ff\nmatch=\(.colours.primary)ff\nselection=\(.colours.primaryContainer)ff\nselection-text=\(.colours.onPrimaryContainer)ff\nselection-match=\(.colours.primary)ff\ncounter=\(.colours.outline)ff\nborder=\(.colours.primary)ff"' "$scheme" > "$tmp"
      mv "$tmp" "$out/fuzzel.ini"
    '';
  };
in
{
  systemd.user.services.fuzzel-theme-sync = {
    Unit.Description = "Render fuzzel.ini from the caelestia scheme";
    Service = {
      Type = "oneshot";
      ExecStart = "${themeSync}/bin/fuzzel-theme-sync";
    };
    # Populate once at login, before the first menu is opened.
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Re-render whenever caelestia rewrites the scheme. PathChanged fires after the
  # writer closes the file, so we never read a half-written scheme.
  systemd.user.paths.fuzzel-theme-sync = {
    Unit.Description = "Watch the caelestia scheme for fuzzel re-theming";
    Path.PathChanged = "%h/.local/state/caelestia/scheme.json";
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
