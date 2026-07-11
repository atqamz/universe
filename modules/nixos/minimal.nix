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

  environment.systemPackages = with pkgs; [
    curl
    htop
    git
    vim
    wget
    fastfetch
  ];

  system.stateVersion = "26.05";
}
