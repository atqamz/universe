{ pkgs, ... }:
let
  dotfiles = "$HOME/dotfiles";
  sync = pkgs.writeShellApplication {
    name = "dotfiles-sync";
    runtimeInputs = with pkgs; [
      git
      coreutils
      libnotify
    ];
    text = ''
      dotfiles="${dotfiles}"
      if [ ! -d "$dotfiles/.git" ]; then
        echo "dotfiles not bootstrapped; run: nix run .#bootstrap" >&2
        exit 0
      fi

      if [ -n "$(git -C "$dotfiles" status --porcelain --untracked-files=no)" ]; then
        notify-send "dotfiles-sync" "local dotfiles changes uncommitted — skipping pull" || true
        echo "dotfiles dirty, skipping pull" >&2
        exit 0
      fi

      git -C "$dotfiles" pull --ff-only || \
        notify-send "dotfiles-sync" "dotfiles pull not fast-forward — diverged, skipping" || true
    '';
  };
in
{
  systemd.user.services.dotfiles-sync = {
    Unit.Description = "Pull dotfiles";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/dotfiles-sync";
    };
  };

  systemd.user.timers.dotfiles-sync = {
    Unit.Description = "Periodic dotfiles sync";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "5min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
