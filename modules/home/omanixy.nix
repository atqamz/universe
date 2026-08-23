{ inputs, ... }:
{
  imports = [ inputs.omanixy.homeManagerModules.default ];

  programs.omanixy = {
    enable = true;
    features = [
      "audio"
      "bluetooth"
      "launcher"
      "monitor"
      "network"
      "notification"
      "power"
      "screenshot"
      "weather"
    ];
    security = {
      lock.enable = true;
      idle.enable = true;
      polkit.agent.enable = true;
      notifications.daemon.enable = true;
    };
  };

  universe.doctor = {
    activeUserServices = [ "omanixy-shell" ];
    commands = [ "omanixy-shell" ];
  };
}
