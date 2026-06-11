{ config, ... }:
{
  users.users.atqa = {
    isNormalUser = true;
    description = "Atqa Munzir";
    hashedPasswordFile = config.sops.secrets.atqa-password.path;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
