_: {
  sops = {
    # Root decrypts with the host SSH key (present from first boot), converted
    # to an age identity internally by sops-nix. No user gpg bootstrap needed.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      atqa-password = {
        sopsFile = ./secrets/atqa-password.sops.yaml;
        # Decrypted before users are created so it can back hashedPasswordFile.
        neededForUsers = true;
      };

      # Tailscale OAuth client secret consumed by tailscaled-autoconnect at boot.
      tailscale-oauth.sopsFile = ./secrets/tailscale-oauth.sops.yaml;

      # Read-only deploy key for the private vault repo. Owned by atqa so
      # secrets-bootstrap clones the vault over ssh with no interactive gh auth.
      vault-deploy-key = {
        sopsFile = ./secrets/vault-deploy-key.sops.yaml;
        owner = "atqa";
        mode = "0400";
      };
    };
  };
}
