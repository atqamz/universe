_: {
  imports = [ ../../modules/nixos/github-runner.nix ];

  services.orgRunner = {
    enable = true;
    count = 4;
    memory = "7g";
    cpus = "2.5";
  };

  hardware.nvidia.prime = {
    amdgpuBusId = "PCI:5:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };
}
