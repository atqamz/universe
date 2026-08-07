{ config, ... }:
{
  imports = [
    ./power.nix
    ./video.nix
  ];

  boot = {
    extraModulePackages = [ config.boot.kernelPackages.acer-wmi-battery ];
    kernelModules = [ "acer_wmi_battery" ];
    extraModprobeConfig = "options acer_wmi_battery enable_health_mode=1";
  };

  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };
}
