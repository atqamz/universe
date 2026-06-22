{ config, pkgs, ... }:
{
  users.users.atqa = {
    isNormalUser = true;
    description = "Atqa Munzir";
    hashedPasswordFile = config.sops.secrets.atqa-password.path;
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
    ];
  };

  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = false;
}
