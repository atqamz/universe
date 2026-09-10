{ lib, pkgs, ... }:
{
  imports = [
    ./minimal.nix
    ./always-on.nix
    ./auto-upgrade.nix
    ./earlyoom.nix
    ./nix-ld.nix
    ./virtualisation.nix
  ];

  system.autoUpgrade.operation = lib.mkForce "boot";
  programs.gnupg.agent.pinentryPackage = lib.mkForce pkgs.pinentry-curses;
}
