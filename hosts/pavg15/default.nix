_: {
  imports = [
    ./hardware.nix
    ../disko.nix
    ./ci-storage.nix
    ./runner.nix
  ];

  networking.hostName = "pavg15";
}
