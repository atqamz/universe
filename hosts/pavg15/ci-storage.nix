_: {
  # The 1 TB sda is a spinning HGST laptop drive, so it holds only what tolerates
  # seek latency: the LFS object cache, image stores and the light runners'
  # throwaway workdirs. Unity's Library churns millions of small files and the
  # bare mirrors sit in the read path of every checkout through git alternates,
  # so both stay on the NVMe under /var/lib/ci. Mounted by UUID rather than
  # declared through disko because the filesystem already exists and keeps prior
  # contents.
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
