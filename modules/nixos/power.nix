{ pkgs, ... }:
{
  services = {
    power-profiles-daemon.enable = true;
    upower.enable = true;
    udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    '';
  };

  hardware = {
    i2c.enable = true;

    bluetooth = {
      enable = true;
      settings.General.Experimental = true;
    };
  };
}
