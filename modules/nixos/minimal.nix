{ pkgs, ... }:
{
  imports = [
    ./boot.nix
    ./earlyoom.nix
    ./gnupg.nix
    ./gpu.nix
    ./locale.nix
    ./network.nix
    ./nix.nix
    ./power.nix
    ./secrets.nix
    ./users.nix
    ./virtualisation.nix
  ];

  programs.nix-ld.enable = true;

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
