{ pkgs, config, ... }:
let
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
          echo 42000000 >"$rapl/constraint_0_power_limit_uw"
          echo 54000000 >"$rapl/constraint_1_power_limit_uw"
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
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
      package = pkgs.steam.override {
        extraEnv = {
          __NV_PRIME_RENDER_OFFLOAD = "1";
          __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          __VK_LAYER_NV_optimus = "NVIDIA_only";
        };
      };
    };

    gamescope.enable = true;

    gamemode = {
      enable = true;
      settings.custom = {
        start = "/run/wrappers/bin/sudo /run/current-system/sw/bin/gaming-power on";
        end = "/run/wrappers/bin/sudo /run/current-system/sw/bin/gaming-power off";
      };
    };
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

  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt
    gamingPower
  ];
}
