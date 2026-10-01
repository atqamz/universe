_: {
  imports = [
    ./hardware.nix
    ../disko.nix
    ./ci-storage.nix
    ./runner.nix
    ./alloy.nix
  ];

  networking.hostName = "pavg15";
}
