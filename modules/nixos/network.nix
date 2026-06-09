{ config, ... }:
{
  networking.networkmanager.enable = true;

  services.openssh.enable = true;
  services.tailscale.enable = true;
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
