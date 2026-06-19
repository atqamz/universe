{ pkgs, ... }:
{
  imports = [
    ../pavg15/hardware.nix
    ../pavg15/disko.nix
  ];

  networking.hostName = "pavg15";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.nvidia.prime = {
    amdgpuBusId = "PCI:5:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  # Minimal install: no desktop environment, no gaming, no heavy IDEs.
  # Only what's needed to boot, network, ssh, bootstrap secrets/brain,
  # and then rebuild to the full pavg15 config.
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
  ];

  system.stateVersion = "26.05";
}
