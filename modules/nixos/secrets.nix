_: {
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      atqa-password = {
        sopsFile = ./secrets/atqa-password.sops.yaml;
        neededForUsers = true;
      };

      tailscale-oauth.sopsFile = ./secrets/tailscale-oauth.sops.yaml;

      vault-deploy-key = {
        sopsFile = ./secrets/vault-deploy-key.sops.yaml;
        owner = "atqa";
        mode = "0400";
      };

      ninerouter-api-key = {
        sopsFile = ./secrets/ninerouter-api-key.sops.yaml;
        owner = "atqa";
        mode = "0400";
      };
    };
  };
}
