{ pkgs, lib, ... }:
let
  prime = import ../../lib/prime.nix { inherit lib; };
in
{
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
      package = pkgs.steam.override {
        extraEnv = prime.env;
      };
    };

    gamescope.enable = true;

    gamemode.enable = true;
  };

  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt
  ];
}
