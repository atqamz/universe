{ config, ... }:
{
  services.mako.enable = true;

  systemd.user.services.mako = {
    Unit = {
      Description = "Mako notification daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      StartLimitBurst = 5;
      StartLimitIntervalSec = "60s";
    };
    Service = {
      ExecStart = "${config.services.mako.package}/bin/mako";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  universe.doctor.activeUserServices = [ "mako" ];
}
