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
      pkgs.coreutils
      pkgs.power-profiles-daemon
    ];
    text = ''
      rapl=/sys/class/powercap/intel-rapl:0
      state=/run/sfx14-power-mode

      set_rapl() {
        printf '%s\n' "$1" >"$rapl/constraint_0_power_limit_uw"
        printf '%s\n' "$1" >"$rapl/constraint_1_power_limit_uw"
      }

      set_epp() {
        for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
          printf '%s\n' "$1" >"$f"
        done
      }

      apply() {
        case "$1" in
          low)
            set_rapl 15000000
            powerprofilesctl set power-saver
            set_epp power
            ;;
          normal)
            set_rapl 20000000
            powerprofilesctl set balanced
            set_epp balance_power
            ;;
          high)
            set_rapl 25000000
            powerprofilesctl set balanced
            set_epp balance_performance
            ;;
          *)
            echo "usage: sfx14-power low|normal|high|restore" >&2
            exit 1
            ;;
        esac
        printf '%s\n' "$1" >"$state"
      }

      mode="''${1:-}"
      if [ "$mode" = restore ]; then
        mode="$(cat "$state" 2>/dev/null || printf '%s\n' normal)"
      fi
      apply "$mode"
    '';
  };
in
{
  universe.doctor.activeSystemServices = [
    "gpu-undervolt"
    "sfx14-power-default"
  ];

  environment.systemPackages = [ powerMode ];

  hardware.i2c.enable = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';

  programs.gamemode.settings.custom = {
    start = "/run/wrappers/bin/sudo /run/current-system/sw/bin/sfx14-power high";
    end = "/run/wrappers/bin/sudo /run/current-system/sw/bin/sfx14-power normal";
  };

  services.undervolt = {
    enable = true;
    useTimer = false;
    p1 = {
      limit = 20;
      window = 28.0;
    };
    p2 = {
      limit = 20;
      window = 2.44;
    };
  };

  systemd.services = {
    sfx14-power-default = {
      description = "Apply the default SFX14 power mode";
      wantedBy = [ "graphical.target" ];
      after = [
        "undervolt.service"
        "power-profiles-daemon.service"
      ];
      requires = [ "power-profiles-daemon.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${powerMode}/bin/sfx14-power normal";
      };
    };

    gpu-undervolt = {
      description = "Apply the SFX14 NVIDIA voltage-frequency policy";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${gpuUndervolt}/bin/gpu-undervolt";
      };
    };
  };

  powerManagement.resumeCommands = ''
    ${powerMode}/bin/sfx14-power restore
    ${gpuUndervolt}/bin/gpu-undervolt
  '';
}
