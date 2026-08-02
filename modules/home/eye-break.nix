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
  systemd.user = {
    services.eye-break = {
      Unit = {
        Description = "Remind me to look away from the screen";
        ConditionEnvironment = "WAYLAND_DISPLAY";
        OnFailure = [ "notify-failure@%n.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe eyeBreak;
      };
    };

    timers.eye-break = {
      Unit.Description = "Remind me to look away from the screen every 20 minutes";
      Timer = {
        OnActiveSec = "20min";
        OnUnitActiveSec = "20min";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
