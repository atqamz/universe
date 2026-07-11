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
  gamingPower = pkgs.writeShellApplication {
    name = "gaming-power";
    runtimeInputs = [
      config.hardware.nvidia.package.bin
      pkgs.systemd
    ];
    text = ''
      rapl=/sys/class/powercap/intel-rapl:0
      epp() { for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo "$1" >"$f"; done; }
      case "''${1:-}" in
        on)
          systemctl stop undervolt.timer undervolt.service
          echo 32000000 >"$rapl/constraint_0_power_limit_uw"
          echo 36000000 >"$rapl/constraint_1_power_limit_uw"
          epp performance
          nvidia-smi -lgc 210,1300
          ;;
        off)
          systemctl restart gpu-undervolt.service
          systemctl restart undervolt.service
          systemctl start undervolt.timer
          epp balance_power
          ;;
        *)
          echo "usage: gaming-power on|off" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  imports = [
    ./hardware.nix
    ../disko.nix
  ];

  networking.hostName = "sfx14";

  boot = {
    loader.systemd-boot.configurationLimit = 3;
    extraModulePackages = [ config.boot.kernelPackages.acer-wmi-battery ];
    kernelModules = [ "acer_wmi_battery" ];
    extraModprobeConfig = "options acer_wmi_battery enable_health_mode=1";
  };

  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  environment.systemPackages = [ gamingPower ];

  programs.gamemode.settings.custom = {
    start = "/run/wrappers/bin/sudo /run/current-system/sw/bin/gaming-power on";
    end = "/run/wrappers/bin/sudo /run/current-system/sw/bin/gaming-power off";
  };

  security.sudo.extraRules = [
    {
      users = [ "atqa" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/gaming-power";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  systemd.services.cpu-epp = {
    description = "bias CPU to balance_power EPP by default";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "cpu-epp" ''
        for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo balance_power >"$f"; done
      '';
    };
  };

  services.undervolt = {
    enable = true;
    useTimer = true;
    p1 = {
      limit = 25;
      window = 28.0;
    };
    p2 = {
      limit = 25;
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
}
