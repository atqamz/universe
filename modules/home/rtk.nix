{
  pkgs,
  lib,
  ...
}:
let
  runtime = [ pkgs.rtk ];

  ensure = pkgs.writeShellApplication {
    name = "rtk-init";
    runtimeInputs = runtime;
    text = ''
      rtk init -g --auto-patch || true
    '';
  };
in
{
  home.activation.rtkInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${ensure}/bin/rtk-init
  '';

  systemd.user.services.rtk-init = {
    Unit.Description = "Re-apply rtk hook for Claude Code";
    Service = {
      Type = "oneshot";
      ExecStart = "${ensure}/bin/rtk-init";
    };
  };

  systemd.user.timers.rtk-init = {
    Unit.Description = "Daily rtk hook refresh";
    Timer = {
      OnStartupSec = "10min";
      OnCalendar = "daily";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
