{ pkgs, lib, ... }:
let
  eyeBreak = pkgs.writeShellApplication {
    name = "eye-break";
    runtimeInputs = [ pkgs.libnotify ];
    text = ''
      notify-send -a eye-break -u low -t 20000 "Look away" "20 seconds, something 6 metres out"
    '';
  };
in
{
  services.userTimers.eye-break = {
    description = "Remind me to look away from the screen";
    timerDescription = "Remind me to look away from the screen every 20 minutes";
    command = lib.getExe eyeBreak;
    unitExtra.ConditionEnvironment = "WAYLAND_DISPLAY";
    wantedBy = [ "graphical-session.target" ];
    timer = {
      OnActiveSec = "20min";
      OnUnitActiveSec = "20min";
    };
  };
}
