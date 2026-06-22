{ config, ... }:
{
  system.autoUpgrade = {
    enable = true;
    flake = "github:atqamz/universe#${config.networking.hostName}";
    dates = "*:0/5";
    randomizedDelaySec = "60";
    flags = [
      "--refresh"
      "-L"
    ];
    operation = "switch";
  };
}
