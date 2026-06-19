{ pkgs, ... }:
{
  imports = [
    ./nix.nix
    ./boot.nix
    ./network.nix
    ./gpu.nix
    ./users.nix
    ./gnupg.nix
    ./secrets.nix
    ./locale.nix
    ./power.nix
    ./earlyoom.nix
  ];

  # Enough to network, ssh, bootstrap secrets/brain, and rebuild to full config.
  environment.systemPackages = with pkgs; [
    curl
    htop
  ];
}
