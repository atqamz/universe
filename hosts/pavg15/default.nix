{ pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  networking.hostName = "pavg15";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.nvidia.prime = {
    amdgpuBusId = "PCI:5:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
  ];

  system.stateVersion = "26.05";
}
