{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    open = true; # Turing supports the open kernel modules
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime.offload = {
      enable = true;
      enableOffloadCmd = true;
    };
  };
}
