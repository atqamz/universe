{ pkgs, ... }:
let
  brain = "$HOME/brain";
  sync = pkgs.writeShellApplication {
    name = "brain-sync";
    runtimeInputs = with pkgs; [
      git
      coreutils
      libnotify
    ];
    text = ''
      brain="${brain}"
      if [ ! -d "$brain/.git" ]; then
        echo "brain not bootstrapped; run: nix run .#brain-bootstrap" >&2
        exit 0
      fi

      if [ -n "$(git -C "$brain" status --porcelain)" ]; then
        notify-send "brain-sync" "local brain changes uncommitted — skipping pull" || true
        echo "brain dirty, skipping pull" >&2
        exit 0
      fi

      git -C "$brain" pull --ff-only || \
        notify-send "brain-sync" "brain pull not fast-forward — diverged, skipping" || true
    '';
  };
in
{
  systemd.user.services.brain-sync = {
    Unit.Description = "Pull canonical brain memory";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/brain-sync";
    };
  };

  systemd.user.timers.brain-sync = {
    Unit.Description = "Periodic brain sync";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
