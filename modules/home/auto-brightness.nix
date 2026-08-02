{ hostname, lib, ... }:
let
  alsHost = "sfx14";
  hasAls = hostname == alsHost;
in
{
  services.wluma = {
    enable = hasAls;
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
      output.backlight = [
        {
          name = "eDP-1";
          path = "/sys/class/backlight/intel_backlight";
          capturer = "wayland";
        }
      ];
    };
  };

  systemd.user.services = lib.mkIf hasAls {
    wluma.Unit.OnFailure = [ "notify-failure@%n.service" ];
  };
}
