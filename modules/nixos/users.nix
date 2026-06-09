_: {
  users.users.atqa = {
    isNormalUser = true;
    description = "Atqa Munzir";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
