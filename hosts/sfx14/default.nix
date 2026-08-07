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
  powerMode = pkgs.writeShellApplication {
    name = "sfx14-power";
    runtimeInputs = [
      config.hardware.nvidia.package.bin
      pkgs.systemd
      pkgs.power-profiles-daemon
    ];
    text = ''
      rapl=/sys/class/powercap/intel-rapl:0

      set_rapl() {
        echo "$1" >"$rapl/constraint_0_power_limit_uw"
        echo "$2" >"$rapl/constraint_1_power_limit_uw"
      }

      epp() {
        for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
          echo "$1" >"$f"
        done
      }

      case "''${1:-}" in
        normal)
          set_rapl 20000000 20000000
          systemctl start undervolt.timer
          systemctl restart gpu-undervolt.service
          powerprofilesctl set balanced
          epp balance_power
          ;;
        low)
          systemctl stop undervolt.timer
          set_rapl 15000000 15000000
          powerprofilesctl set power-saver
          epp power
          ;;
        high)
          systemctl stop undervolt.timer
          set_rapl 25000000 25000000
          powerprofilesctl set balanced
          epp balance_performance
          nvidia-smi -lgc 210,1300
          ;;
        *)
          echo "usage: sfx14-power low|normal|high" >&2
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

  hardware = {
    graphics.extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
    nvidia.prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  environment = {
    sessionVariables.LIBVA_DRIVER_NAME = "iHD";
    systemPackages = [ powerMode ];
  };

  programs.gamemode.settings.custom = {
    start = "/run/wrappers/bin/sudo /run/current-system/sw/bin/sfx14-power high";
    end = "/run/wrappers/bin/sudo /run/current-system/sw/bin/sfx14-power normal";
  };

  security.sudo.extraRules = [
    {
      users = [ "atqa" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/sfx14-power";
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
      limit = 20;
      window = 28.0;
    };
    p2 = {
      limit = 20;
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
