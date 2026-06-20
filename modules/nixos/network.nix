{ config, ... }:
{
  networking.networkmanager.enable = true;

  services = {
    resolved.enable = true;

    openssh.enable = true;
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
}
