{ pkgs, ... }:
{
  programs.foot.enable = true;

  # GLib resolves a Terminal=true desktop entry against a hardcoded list whose
  # first member is xdg-terminal-exec; this host installs none of the others
  # (gnome-terminal, mate-terminal, xfce4-terminal, tilix, konsole, nxterm,
  # color-xterm, rxvt, dtterm, io.elementary.terminal). Without one, gtk-launch
  # refuses every terminal entry with "Unable to find terminal required for
  # application", which is what the Omanixy launcher runs (atqamz/omanixy#50).
  # x-scheme-handler/terminal does not help: GLib 2.88 never consults it.
  home.packages = [ pkgs.xdg-terminal-exec ];
  xdg.configFile."xdg-terminals.list".text = "foot.desktop\n";
}
