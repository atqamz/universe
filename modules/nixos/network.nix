{ config, pkgs, ... }:
let
  # sshd asks this for "%u"'s keys at connect time; we answer only for atqa and
  # pull live from github.com/atqamz.keys, so a key rotated on GitHub works
  # without a redeploy. Empty output for any other user. Network failure falls
  # through to Tailscale SSH.
  githubKeys = pkgs.writeShellScript "ssh-github-keys" ''
    [ "$1" = "atqa" ] || exit 0
    ${pkgs.curl}/bin/curl -fsS --max-time 5 \
      --cacert ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
      https://github.com/atqamz.keys || true
  '';
in
{
  networking.networkmanager.enable = true;

  services.openssh = {
    enable = true;
    authorizedKeysCommand = "${githubKeys} %u";
    # Unprivileged helper user, per sshd's requirement for AuthorizedKeysCommand.
    authorizedKeysCommandUser = "nobody";
  };
  services.tailscale.enable = true;
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
