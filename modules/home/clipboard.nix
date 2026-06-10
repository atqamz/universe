{ pkgs, ... }:
{
  # caelestia clipboard reads cliphist's history; nothing populates it unless
  # wl-paste watches the selection. Bind to the graphical session uwsm owns.
  systemd.user.services.cliphist = {
    Unit = {
      Description = "Clipboard history (cliphist via wl-paste)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
