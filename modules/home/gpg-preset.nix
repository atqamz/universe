{ pkgs, ... }:
let
  preset = pkgs.writeShellApplication {
    name = "gpg-preset";
    runtimeInputs = with pkgs; [
      gnupg
      gawk
      coreutils
    ];
    text = ''
      # Preset the gpg key passphrase into gpg-agent so the [A] auth subkey
      # signs git-over-ssh (github) and the [S] subkey signs commits without an
      # interactive pinentry. gpg-agent's passphrase cache is cleared on reboot,
      # so this runs at every login. The passphrase is placed by the vault's
      # import.sh (private, never in the public repo).
      pp="$HOME/.gnupg/.preset-passphrase"
      if [ ! -r "$pp" ]; then
        echo "no preset passphrase ($pp); run secrets-bootstrap first" >&2
        exit 0
      fi
      gpg-connect-agent /bye >/dev/null 2>&1 || true
      presetbin="$(gpgconf --list-dirs libexecdir)/gpg-preset-passphrase"
      gpg --batch --with-colons --with-keygrip --list-secret-keys \
        | awk -F: '/^grp:/ {print $10}' | sort -u | while read -r kg; do
            [ -n "$kg" ] || continue
            "$presetbin" --preset "$kg" < "$pp" || true
          done
    '';
  };
in
{
  systemd.user.services.gpg-preset = {
    Unit = {
      Description = "Preset gpg passphrase into gpg-agent for headless signing";
      After = [ "gpg-agent.socket" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${preset}/bin/gpg-preset";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
