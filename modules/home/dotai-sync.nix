{ pkgs, ... }:
let
  dotai = "$HOME/dotai";
  sync = pkgs.writeShellApplication {
    name = "dotai-sync";
    runtimeInputs = with pkgs; [
      git
      coreutils
      libnotify
    ];
    text = ''
      dotai="${dotai}"
      if [ ! -d "$dotai/.git" ]; then
        echo "dotai not bootstrapped; run: nix run .#bootstrap" >&2
        exit 0
      fi

      if [ -n "$(git -C "$dotai" status --porcelain --untracked-files=no)" ]; then
        notify-send "dotai-sync" "local dotai changes uncommitted — skipping pull" || true
        echo "dotai dirty, skipping pull" >&2
        exit 0
      fi

      git -C "$dotai" pull --ff-only || \
        notify-send "dotai-sync" "dotai pull not fast-forward — diverged, skipping" || true
    '';
  };
in
{
  systemd.user.services.dotai-sync = {
    Unit.Description = "Pull dotai";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/dotai-sync";
    };
  };

  systemd.user.timers.dotai-sync = {
    Unit.Description = "Periodic dotai sync";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "5min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
