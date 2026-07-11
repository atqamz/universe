{ config, ... }:
{
  system.autoUpgrade = {
    enable = true;
    flake = "git+https://github.com/atqamz/universe#${config.networking.hostName}";
    dates = "00/12:00";
    randomizedDelaySec = "60";
    flags = [
      "--refresh"
      "-L"
    ];
    operation = "switch";
  };
}
