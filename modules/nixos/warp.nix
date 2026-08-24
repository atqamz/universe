{ config, pkgs, ... }:
let
  warpWireGuard = pkgs.writeShellApplication {
    name = "warp-wireguard";
    runtimeInputs = [
      config.services.cloudflare-warp.package
      pkgs.gnugrep
    ];
    text = ''
      settings="$(warp-cli settings)"
      if printf '%s\n' "$settings" | grep -qi 'protocol.*WireGuard'; then
        exit 0
      fi

      warp-cli tunnel protocol set WireGuard
      settings="$(warp-cli settings)"
      if ! printf '%s\n' "$settings" | grep -qi 'protocol.*WireGuard'; then
        printf '%s\n' "$settings" >&2
        echo "WARP tunnel protocol is not WireGuard after reconciliation" >&2
        exit 1
      fi
    '';
  };
in
{
  services.cloudflare-warp.enable = true;

  systemd.services.cloudflare-warp-wireguard = {
    description = "Pin Cloudflare WARP tunnel protocol to WireGuard";
    requires = [ "cloudflare-warp.service" ];
    after = [ "cloudflare-warp.service" ];
    wantedBy = [
      "multi-user.target"
      "cloudflare-warp.service"
    ];
    startLimitIntervalSec = 60;
    startLimitBurst = 6;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${warpWireGuard}/bin/warp-wireguard";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "30s";
    };
  };

  systemd.timers.cloudflare-warp-wireguard = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitInactiveSec = "5min";
      Unit = "cloudflare-warp-wireguard.service";
    };
  };

  universe.doctor = {
    activeSystemServices = [ "cloudflare-warp" ];
    systemTimers = [ "cloudflare-warp-wireguard" ];
  };
}
