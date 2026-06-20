{ pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "sfx14";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    fastfetch
  ];

  system.stateVersion = "26.05";
}
