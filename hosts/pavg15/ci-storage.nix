_: {
  fileSystems."/var/lib/ci/bulk" = {
    device = "/dev/disk/by-uuid/7cdaecc2-1294-4c50-9f49-0a5b29ca9dbd";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "nofail"
    ];
  };
}
