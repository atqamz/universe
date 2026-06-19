{ config, ... }:
{
  networking.networkmanager.enable = true;

  services = {
    # systemd-resolved arbitrates DNS so Tailscale MagicDNS and Cloudflare WARP
    # coexist. Without it, whichever daemon writes /etc/resolv.conf last wins:
    # WARP clobbers it with its own resolver and MagicDNS names (*.ts.net) stop
    # resolving, so outbound `ssh <tailnet-host>` fails by name. resolved does
    # per-domain split routing instead -- Tailscale registers ~ts.net -> the
    # MagicDNS resolver, WARP registers everything else.
    resolved.enable = true;

    # SSH is handled by Tailscale SSH: tailscaled runs its own SSH server on the
    # tailnet, auth governed by the tailnet ACL (keyless, no authorized_keys).
    # `set --ssh` applies this declaratively on every activation. sshd stays
    # enabled as a shadowed break-glass if Tailscale SSH is ever turned off.
    openssh.enable = true;
    tailscale = {
      enable = true;
      # OAuth client secret (long-lived, revoke-only -- no 90-day auth-key
      # expiry). Auto-joins on first boot, so a fresh reinstall lands on the
      # tailnet with no console step. OAuth-authed nodes must be tagged; tagged
      # nodes never key-expire, so the node stays up permanently too.
      authKeyFile = config.sops.secrets.tailscale-oauth.path;
      extraUpFlags = [
        "--ssh"
        "--advertise-tags=tag:universe"
      ];
      extraSetFlags = [ "--ssh" ];
    };
  };

  # Port 22 is reachable only over the tailnet; nothing is exposed publicly.
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
