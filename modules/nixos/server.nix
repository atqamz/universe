{ lib, pkgs, ... }:
{
  imports = [
    ./minimal.nix
    ./always-on.nix
    ./auto-upgrade.nix
    ./earlyoom.nix
    ./nix-ld.nix
    ./overlays.nix
    ./virtualisation.nix
  ];

  # A CI host must never restart a running job to apply an update, and a Unity
  # build here runs for hours. The new generation waits for the next boot.
  system.autoUpgrade.operation = lib.mkForce "boot";

  # Nothing on a server has a display to prompt on.
  programs.gnupg.agent.pinentryPackage = lib.mkForce pkgs.pinentry-curses;
}
