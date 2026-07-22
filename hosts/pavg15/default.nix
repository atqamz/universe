_: {
  imports = [
    ./hardware.nix
    ../disko.nix
    ../../modules/nixos/github-runner.nix
  ];

  networking.hostName = "pavg15";

  services.pavg15Runner = {
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
