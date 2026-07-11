{ config, pkgs, ... }:
{
  users.users.atqa = {
    isNormalUser = true;
    description = "Atqa Munzir";
    hashedPasswordFile = config.sops.secrets.atqa-password.path;
    shell = pkgs.bashInteractive;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
