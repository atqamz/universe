{ pkgs, config, ... }:
let
  gpuOffset = pkgs.writeText "gpu-offset.py" ''
    import pynvml
    pynvml.nvmlInit()
    handle = pynvml.nvmlDeviceGetHandleByIndex(0)
    pynvml.nvmlDeviceSetGpcClkVfOffset(handle, 200)
    pynvml.nvmlShutdown()
  '';
  gpuUndervolt = pkgs.writeShellApplication {
    name = "gpu-undervolt";
    runtimeInputs = [
      config.hardware.nvidia.package.bin
      (pkgs.python3.withPackages (ps: [ ps.nvidia-ml-py ]))
    ];
    text = ''
      nvidia-smi -pm 1
      nvidia-smi -lgc 210,1540
      python3 ${gpuOffset}
    '';
  };
in
{
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/nixos/hermes-isolated.nix
  ];

  networking.hostName = "sfx14";

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.systemd-boot.configurationLimit = 3;
    extraModulePackages = [ config.boot.kernelPackages.acer-wmi-battery ];
    kernelModules = [ "acer_wmi_battery" ];
    extraModprobeConfig = "options acer_wmi_battery enable_health_mode=1";
  };

  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    fastfetch
  ];

  services.undervolt = {
    enable = true;
    useTimer = true;
    p1 = {
      limit = 35;
      window = 28.0;
    };
    p2 = {
      limit = 35;
      window = 2.44;
    };
  };

  systemd.services.gpu-undervolt = {
    description = "NVIDIA undervolt: lock 1540MHz + 200MHz clock offset (~650mV)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${gpuUndervolt}/bin/gpu-undervolt";
    };
  };

  system.stateVersion = "26.05";
}
