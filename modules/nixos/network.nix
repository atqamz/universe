{
  config,
  lib,
  pkgs,
  ...
}:
let
  tailscaleBootstrap = pkgs.writeShellApplication {
    name = "tailscale-bootstrap";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      systemctl start --wait tailscaled-autoconnect.service
      systemctl start --wait tailscaled-set.service
    '';
  };
in
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
      tailscaled-set.requires = [ "tailscaled-autoconnect.service" ];
      tailscaled-set.serviceConfig.TimeoutStartSec = "300s";

      tailscale-bootstrap = {
        description = "Retryable asynchronous Tailscale bootstrap";
        wantedBy = [ ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${tailscaleBootstrap}/bin/tailscale-bootstrap";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "30s";
          TimeoutStartSec = "300s";
        };
      };
    };

    timers.tailscale-bootstrap = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        Unit = "tailscale-bootstrap.service";
      };
    };
  };

  universe.doctor = {
    activeSystemServices = [ "tailscale-bootstrap" ];
    systemTimers = [ "tailscale-bootstrap" ];
  };
}
