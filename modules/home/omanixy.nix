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
  };

  universe.doctor = {
    activeUserServices = [ "omanixy-shell" ];
    commands = [ "omanixy-shell" ];
  };
}
