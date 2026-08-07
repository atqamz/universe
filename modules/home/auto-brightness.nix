{ lib, osConfig, ... }:
let
  enabled = osConfig.universe.capabilities.ambientLight;
in
{
  services.wluma = {
    inherit enable;
    settings = {
      als.iio = {
        path = "/sys/bus/iio/devices";
        thresholds = {
          "0" = "night";
          "20" = "dark";
          "80" = "dim";
          "250" = "normal";
          "500" = "bright";
          "800" = "outdoors";
        };
      };
      output = {
        backlight = [
          {
            name = "eDP-1";
            path = "/sys/class/backlight/intel_backlight";
            capturer = "wayland";
          }
        ];
        ddcutil = [
          {
            name = "(DP-1)";
            identifier = "USB C2 demoset-1 RTK";
            capturer = "wayland";
          }
        ];
      };
    };
  };

  universe.doctor.activeUserServices = lib.optional enabled "wluma";

  systemd.user.services = lib.mkIf enabled {
    wluma.Unit.OnFailure = [ "notify-failure@%n.service" ];
  };
}
