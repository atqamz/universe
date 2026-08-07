{ pkgs, ... }:
{
  imports = [
    ./universe.nix
    ./boot.nix
    ./gnupg.nix
    ./locale.nix
    ./network.nix
    ./nix.nix
    ./secrets.nix
    ./users.nix
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
