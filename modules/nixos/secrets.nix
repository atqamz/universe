_: {
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      atqa-password = {
        sopsFile = ./secrets/atqa-password.sops.yaml;
        neededForUsers = true;
      };

      tailscale-oauth.sopsFile = ./secrets/tailscale-oauth.sops.yaml;

      alloy-env = {
        sopsFile = ./secrets/alloy-env.sops.yaml;
        restartUnits = [ "alloy.service" ];
      };
    };
  };
}
