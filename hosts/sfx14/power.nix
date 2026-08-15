{ pkgs, config, ... }:
let
  deferredExitCode = 75;

  targetNvidiaModule = "${config.hardware.nvidia.package.open}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/kernel/drivers/video/nvidia.ko.xz";
  targetNvidiaSmi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
  targetNvidiaVersion = config.hardware.nvidia.package.version;

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
      pkgs.coreutils
      config.hardware.nvidia.package.bin
      (pkgs.python3.withPackages (ps: [ ps.nvidia-ml-py ]))
    ];
    text = ''
      current_system="''${UNIVERSE_GPU_CURRENT_SYSTEM:-/run/current-system}"
      booted_system="''${UNIVERSE_GPU_BOOTED_SYSTEM:-/run/booted-system}"
      loaded_version_file="''${UNIVERSE_GPU_LOADED_NVIDIA_VERSION_FILE:-/sys/module/nvidia/version}"
      nvidia_smi="''${UNIVERSE_GPU_NVIDIA_SMI:-nvidia-smi}"
      python3_bin="''${UNIVERSE_GPU_PYTHON:-python3}"
      target_kernel=""
      booted_kernel=""
      loaded_nvidia_version=""
      target_smi_identity=""
      booted_smi_identity=""
      booted_nvidia_module="$booted_system/kernel-modules/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/kernel/drivers/video/nvidia.ko.xz"

      defer() {
        printf 'gpu-undervolt: DEFERRED until reboot: %s\n' "$1" >&2
        printf 'gpu-undervolt: booted kernel=%s\n' "''${booted_kernel:-unavailable}" >&2
        printf 'gpu-undervolt: target kernel=%s\n' "''${target_kernel:-unavailable}" >&2
        printf 'gpu-undervolt: loaded NVIDIA=%s\n' "''${loaded_nvidia_version:-unavailable}" >&2
        printf 'gpu-undervolt: target NVIDIA=%s\n' "${targetNvidiaVersion}" >&2
        printf 'gpu-undervolt: target NVIDIA module=%s\n' "${targetNvidiaModule}" >&2
        printf 'gpu-undervolt: booted NVIDIA module=%s\n' "$booted_nvidia_module" >&2
        printf 'gpu-undervolt: target NVIDIA userspace=%s\n' "''${target_smi_identity:-unavailable}" >&2
        printf 'gpu-undervolt: booted NVIDIA userspace=%s\n' "''${booted_smi_identity:-unavailable}" >&2
        exit ${toString deferredExitCode}
      }

      if [ -r "$loaded_version_file" ]; then
        if IFS= read -r loaded_nvidia_version < "$loaded_version_file"; then
          :
        else
          loaded_nvidia_version=""
        fi
      fi

      if [ -f "${targetNvidiaSmi}" ] \
        && [ -f "$booted_system/sw/bin/nvidia-smi" ]; then
        if target_smi_identity="$(readlink -f -- "${targetNvidiaSmi}" 2>/dev/null)" \
          && booted_smi_identity="$(readlink -f -- "$booted_system/sw/bin/nvidia-smi" 2>/dev/null)"; then
          :
        else
          target_smi_identity=""
          booted_smi_identity=""
        fi
      fi

      if target_kernel="$(readlink -f -- "$current_system/kernel" 2>/dev/null)" \
        && booted_kernel="$(readlink -f -- "$booted_system/kernel" 2>/dev/null)" \
        && [ "$target_kernel" != "$booted_kernel" ]; then
        defer "active boot does not match target kernel generation"
      fi

      if [ -f "${targetNvidiaModule}" ] \
        && [ -f "$booted_nvidia_module" ] \
        && ! cmp -s -- "${targetNvidiaModule}" "$booted_nvidia_module"; then
        defer "NVIDIA kernel module differs from the booted generation"
      fi

      if [ -n "$target_smi_identity" ] \
        && [ -n "$booted_smi_identity" ] \
        && [ "$target_smi_identity" != "$booted_smi_identity" ]; then
        defer "NVIDIA userspace differs from the booted generation"
      fi

      if [ -n "$loaded_nvidia_version" ] \
        && [ "$loaded_nvidia_version" != "${targetNvidiaVersion}" ]; then
        defer "loaded NVIDIA version differs from the target generation"
      fi

      "$nvidia_smi" -pm 1
      "$nvidia_smi" -lgc 210,1540
      "$python3_bin" ${gpuOffset}
    '';
  };

  gpuUndervoltResume = pkgs.writeShellApplication {
    name = "gpu-undervolt-resume";
    text = ''
      gpu_rc=0
      if ${gpuUndervolt}/bin/gpu-undervolt; then
        gpu_rc=0
      else
        gpu_rc=$?
      fi

      case "$gpu_rc" in
        0|${toString deferredExitCode})
          ;;
        *)
          exit "$gpu_rc"
          ;;
      esac
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
    undervolt-sleep.after = [ "sleep-actions.service" ];

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
        SuccessExitStatus = [ deferredExitCode ];
        ExecStart = "${gpuUndervolt}/bin/gpu-undervolt";
      };
    };
  };

  powerManagement.resumeCommands = ''
    ${powerMode}/bin/sfx14-power restore
    ${gpuUndervoltResume}/bin/gpu-undervolt-resume
  '';
}
