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
      pp="$HOME/.gnupg/.preset-passphrase"
      if [ ! -r "$pp" ]; then
        echo "gpg-preset: missing preset passphrase; run 'nix run .#bootstrap'" >&2
        exit 1
      fi
      gpg-connect-agent /bye >/dev/null
      presetbin="$(gpgconf --list-dirs libexecdir)/gpg-preset-passphrase"
      gpg --batch --with-colons --with-keygrip --list-secret-keys \
        | awk -F: '/^grp:/ {print $10}' \
        | sort -u \
        | while read -r kg; do
            [ -n "$kg" ] || continue
            "$presetbin" --preset "$kg" <"$pp"
          done
    '';
  };
in
{
  systemd.user.services.gpg-preset = {
    Unit = {
      Description = "Preset gpg passphrase into gpg-agent for headless signing";
      After = [ "gpg-agent.socket" ];
      OnFailure = [ "notify-failure@%n.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${preset}/bin/gpg-preset";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
