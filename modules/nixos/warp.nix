{
  config,
  lib,
  pkgs,
  ...
}:
let
  warpWireGuard = pkgs.writeShellApplication {
    name = "warp-wireguard";
    runtimeInputs = [
      config.services.cloudflare-warp.package
      pkgs.jq
    ];
    text = ''
      settings="$(warp-cli --json settings)"
      if jq -e '.settings.warp_tunnel_protocol == "wireguard"' <<<"$settings" >/dev/null; then
        exit 0
      fi

      warp-cli tunnel protocol set WireGuard
      settings="$(warp-cli --json settings)"
      if ! jq -e '.settings.warp_tunnel_protocol == "wireguard"' <<<"$settings" >/dev/null; then
        printf '%s\n' "$settings" >&2
        echo "WARP tunnel protocol is not WireGuard after reconciliation" >&2
        exit 1
      fi
    '';
  };
  warpReady = pkgs.writeShellApplication {
    name = "warp-ready";
    runtimeInputs = [
      config.services.cloudflare-warp.package
      pkgs.coreutils
    ];
    text = ''
      for attempt in {1..20}; do
        if warp-cli --json settings >/dev/null; then
          exit 0
        fi
        if [ "$attempt" -lt 20 ]; then
          sleep 1
        fi
      done
      echo "WARP daemon did not become ready within 20 seconds" >&2
      exit 1
    '';
  };
in
{
  services.cloudflare-warp.enable = true;

  systemd = {
    services.cloudflare-warp.serviceConfig.ExecStartPost = lib.getExe warpReady;

    services.cloudflare-warp-wireguard = {
      description = "Pin Cloudflare WARP tunnel protocol to WireGuard";
      requires = [ "cloudflare-warp.service" ];
      after = [ "cloudflare-warp.service" ];
      wantedBy = [
        "multi-user.target"
        "cloudflare-warp.service"
      ];
      unitConfig = {
        StartLimitIntervalSec = 300;
        StartLimitBurst = 6;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${warpWireGuard}/bin/warp-wireguard";
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "30s";
      };
    };

    timers.cloudflare-warp-wireguard = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitInactiveSec = "5min";
        Unit = "cloudflare-warp-wireguard.service";
      };
    };
  };

  universe.doctor = {
    activeSystemServices = [ "cloudflare-warp" ];
    systemTimers = [ "cloudflare-warp-wireguard" ];
  };
}
