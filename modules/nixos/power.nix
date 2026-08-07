_: {
  services = {
    power-profiles-daemon.enable = true;
    upower.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    settings.General.Experimental = true;
  };
}
