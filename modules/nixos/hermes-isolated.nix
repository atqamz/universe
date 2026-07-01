{ pkgs, ... }:
{
  users.groups.hermes = { };

  users.users.hermes = {
    isSystemUser = true;
    group = "hermes";
    home = "/var/lib/hermes-isolated";
    createHome = true;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/hermes-isolated 0750 hermes hermes -"
    "d /var/lib/hermes-isolated/state 0750 hermes hermes -"
    "d /var/lib/hermes-isolated/state/hermes-agent 0700 hermes hermes -"
    "d /var/lib/hermes-isolated/state/hermes 0700 hermes hermes -"
  ];

  systemd.services.hermes-gateway = {
    description = "Hermes Agent isolated gateway";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      User = "hermes";
      Group = "hermes";
      WorkingDirectory = "/var/lib/hermes-isolated/state/hermes-agent";
      Environment = [
        "HOME=/var/lib/hermes-isolated"
        "HERMES_HOME=/var/lib/hermes-isolated/state/hermes-agent"
        "PATH=${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.nodejs_22}/bin:/run/current-system/sw/bin"
      ];
      ExecStart = "/var/lib/hermes-isolated/.local/bin/hermes gateway run";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
