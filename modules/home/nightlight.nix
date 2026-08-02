{ pkgs, ... }:
let
  readingTemp = 3400;
  readingGamma = 80;

  readingMode = pkgs.writeShellApplication {
    name = "reading-mode";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.libnotify
    ];
    text = ''
      if [ "$(hyprctl hyprsunset temperature)" = "${toString readingTemp}" ]; then
        hyprctl hyprsunset reset
        notify-send -a reading-mode -t 2000 "Reading mode off"
      else
        hyprctl hyprsunset temperature ${toString readingTemp}
        hyprctl hyprsunset gamma ${toString readingGamma}
        notify-send -a reading-mode -t 2000 "Reading mode on" "${toString readingTemp}K"
      fi
    '';
  };
in
{
  services.hyprsunset.enable = true;

  systemd.user.services.hyprsunset.Unit.OnFailure = [ "notify-failure@%n.service" ];

  home.packages = [ readingMode ];
}
