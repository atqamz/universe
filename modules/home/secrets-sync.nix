{ pkgs, ... }:
let
  vault = "$HOME/repo/secrets";
  sync = pkgs.writeShellApplication {
    name = "secrets-sync";
    runtimeInputs = with pkgs; [
      git
      gnupg
      sops
      age
      coreutils
      libnotify
    ];
    text = ''
      vault="${vault}"
      if [ ! -d "$vault/.git" ]; then
        echo "vault not bootstrapped; run: nix run .#secrets-bootstrap" >&2
        exit 0
      fi

      # Never clobber un-exported local key material.
      if [ -n "$(git -C "$vault" status --porcelain)" ]; then
        notify-send "secrets-sync" "local vault changes — run 'nix run .#secrets-export'" || true
        echo "vault dirty, skipping pull" >&2
        exit 0
      fi

      git -C "$vault" pull --ff-only
      ( cd "$vault" && ./scripts/import.sh )

      # Fast-forward the password store too, if present.
      if [ -d "$HOME/.password-store/.git" ]; then
        git -C "$HOME/.password-store" pull --ff-only || true
      fi
    '';
  };
in
{
  systemd.user.services.secrets-sync = {
    Unit.Description = "Pull canonical vault and import secrets";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/secrets-sync";
    };
  };

  systemd.user.timers.secrets-sync = {
    Unit.Description = "Periodic secrets vault sync";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
