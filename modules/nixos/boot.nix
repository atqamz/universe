_: {
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    resumeDevice = "/dev/disk/by-partlabel/disk-main-swap";
  };
}
