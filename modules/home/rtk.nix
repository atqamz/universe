{ pkgs, ... }:
let
  ensure = pkgs.writeShellApplication {
    name = "rtk-init";
    runtimeInputs = [ pkgs.rtk ];
    text = ''
      rtk init -g --hook-only --auto-patch
    '';
  };
in
{
  services.userTimers.rtk-init = {
    description = "Re-apply rtk hook for Claude Code";
    timerDescription = "Daily rtk hook refresh";
    command = "${ensure}/bin/rtk-init";
    onActivation = "try";
    timer = {
      OnStartupSec = "10min";
      OnCalendar = "daily";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };
}
