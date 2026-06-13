{ config, ... }:
{
  networking.networkmanager.enable = true;

  # SSH is handled by Tailscale SSH: tailscaled runs its own SSH server on the
  # tailnet, auth governed by the tailnet ACL (keyless, no authorized_keys).
  # `set --ssh` applies this declaratively on every activation. sshd stays
  # enabled as a shadowed break-glass if Tailscale SSH is ever turned off.
  services.openssh.enable = true;
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--ssh" ];
  };

  # Port 22 is reachable only over the tailnet; nothing is exposed publicly.
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
