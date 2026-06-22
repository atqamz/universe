{ pkgs, ... }:
let
  vault = "$HOME/vault";
  sync = pkgs.writeShellApplication {
    name = "vault-sync";
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
        echo "vault not bootstrapped; run: nix run .#bootstrap" >&2
        exit 0
      fi

      if [ -n "$(git -C "$vault" status --porcelain)" ]; then
        notify-send "vault-sync" "local vault changes uncommitted — skipping pull" || true
        echo "vault dirty, skipping pull" >&2
        exit 0
      fi

      git -C "$vault" pull --ff-only || \
        notify-send "vault-sync" "vault pull not fast-forward — diverged, skipping" || true

      ( cd "$vault" && ./scripts/import.sh )
    '';
  };
in
{
  systemd.user.services.vault-sync = {
    Unit.Description = "Pull secrets vault and import";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/vault-sync";
    };
  };

  systemd.user.timers.vault-sync = {
    Unit.Description = "Periodic vault sync";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
