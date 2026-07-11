_: {
  imports = [
    ./hardware.nix
    ../disko.nix
  ];

  networking.hostName = "pavg15";

  hardware.nvidia.prime = {
    amdgpuBusId = "PCI:5:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };
}
