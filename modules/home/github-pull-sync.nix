{ pkgs, ... }:
let
  sync = pkgs.writeShellApplication {
    name = "github-pull-sync";
    runtimeInputs = with pkgs; [
      git
      findutils
      coreutils
    ];
    text = ''
      set -euo pipefail

      root="${"\${HOME}"}/github"
      [ -d "$root" ] || exit 0

      find "$root" -name .git -type d -prune | while read -r gitdir; do
        repo=$(dirname "$gitdir")
        name=''${repo#"$root"/}

        cd "$repo" || continue

        upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || {
          echo "skip $name: no upstream"
          continue
        }

        dirty=$(git status --porcelain 2>/dev/null)
        stashed=""

        if [ -n "$dirty" ]; then
          git stash -u -q 2>/dev/null && stashed=1 || {
            echo "skip $name: stash failed"
            continue
          }
        fi

        if ! git pull --ff-only -q 2>/dev/null; then
          echo "skip $name: pull failed (diverged or error)"
          [ -n "$stashed" ] && git stash pop -q 2>/dev/null || true
          continue
        fi

        if [ -n "$stashed" ]; then
          if ! git stash pop -q 2>/dev/null; then
            echo "warn $name: stash pop conflict, stash kept"
            continue
          fi
        fi

        echo "ok $name"
      done
    '';
  };
in
{
  home.packages = [ sync ];

  systemd.user.services.github-pull-sync = {
    Unit.Description = "Pull all github repos";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/github-pull-sync";
    };
  };

  systemd.user.timers.github-pull-sync = {
    Unit.Description = "Periodic github repo pull";
    Timer = {
      OnStartupSec = "5min";
      OnUnitActiveSec = "15min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
