{ config, lib, ... }:
{
  networking.networkmanager.enable = true;

  services = {
    resolved.enable = true;

    openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscale-oauth.path;
      extraUpFlags = [
        "--ssh"
        "--advertise-tags=tag:universe"
      ];
      extraSetFlags = [ "--ssh" ];
    };
  };

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  systemd = {
    services = {
      tailscaled-autoconnect.wantedBy = lib.mkForce [ ];
      tailscaled-set.wantedBy = lib.mkForce [ ];
    };

    targets.tailscale-bootstrap.unitConfig.Wants = [
      "tailscaled-autoconnect.service"
      "tailscaled-set.service"
    ];

    timers.tailscale-bootstrap = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        Unit = "tailscale-bootstrap.target";
      };
    };
  };

  universe.doctor.systemTimers = [ "tailscale-bootstrap" ];
}
