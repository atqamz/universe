{ pkgs, ... }:
let
  dotagents = "$HOME/dotagents";
  sync = pkgs.writeShellApplication {
    name = "dotagents-sync";
    runtimeInputs = with pkgs; [
      git
      coreutils
      libnotify
    ];
    text = ''
      dotagents="${dotagents}"
      if [ ! -d "$dotagents/.git" ]; then
        echo "dotagents not bootstrapped; run: nix run .#bootstrap" >&2
        exit 0
      fi

      if [ -n "$(git -C "$dotagents" status --porcelain --untracked-files=no)" ]; then
        notify-send "dotagents-sync" "local dotagents changes uncommitted — skipping pull" || true
        echo "dotagents dirty, skipping pull" >&2
        exit 0
      fi

      git -C "$dotagents" pull --ff-only || \
        notify-send "dotagents-sync" "dotagents pull not fast-forward — diverged, skipping" || true
    '';
  };
in
{
  systemd.user.services.dotagents-sync = {
    Unit.Description = "Pull dotagents";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/dotagents-sync";
    };
  };

  systemd.user.timers.dotagents-sync = {
    Unit.Description = "Periodic dotagents sync";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "5min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
