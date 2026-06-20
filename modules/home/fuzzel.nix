{ pkgs, ... }:
let
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
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.paths.fuzzel-theme-sync = {
    Unit.Description = "Watch the caelestia scheme for fuzzel re-theming";
    Path.PathChanged = "%h/.local/state/caelestia/scheme.json";
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
