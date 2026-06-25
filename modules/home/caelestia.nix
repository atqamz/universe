{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  programs.caelestia = {
    enable = true;
    cli.enable = true;
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };
  };

  home.activation.caelestiaShellJson = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfgDir="$HOME/.config/caelestia"
    f="$cfgDir/shell.json"
    run mkdir -p "$cfgDir"
    if [ -L "$f" ]; then run rm -f "$f"; fi
    base="{}"
    if [ -f "$f" ]; then base="$(cat "$f")"; fi
    printf '%s' "$base" | ${pkgs.jq}/bin/jq \
      '.general.idle.lockBeforeSleep=false
       | .general.idle.timeouts=[]
       | .general.apps.explorer=["thunar"]
       | .paths.wallpaperDir="~/Pictures/Wallpapers"' \
      > "$f.tmp" && run mv "$f.tmp" "$f"
  '';
}
