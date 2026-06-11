{ config, ... }:
{
  users.users.atqa = {
    isNormalUser = true;
    description = "Atqa Munzir";
    hashedPasswordFile = config.sops.secrets.atqa-password.path;
    # First-boot net: host key may be absent on the very first switch of a new
    # machine, so the sops secret can fail to decrypt once. Remove after the
    # host-ssh-age recipient is confirmed working on every host.
    initialHashedPassword = "$y$j9T$P87A2tij4JfWSmjrTxjRr/$KsThkNugMFGxEPv8vmdLwflW0BOcFze.h6zKuLA2RY1";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
