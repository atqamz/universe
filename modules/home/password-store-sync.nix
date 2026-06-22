{ pkgs, ... }:
let
  store = "$HOME/.password-store";
  sync = pkgs.writeShellApplication {
    name = "password-store-sync";
    runtimeInputs = with pkgs; [
      git
      coreutils
    ];
    text = ''
      store="${store}"
      if [ ! -d "$store/.git" ]; then
        echo "password-store not bootstrapped; run: nix run .#bootstrap" >&2
        exit 0
      fi

      git -C "$store" pull --ff-only || true
    '';
  };
in
{
  systemd.user.services.password-store-sync = {
    Unit.Description = "Pull password-store";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/password-store-sync";
    };
  };

  systemd.user.timers.password-store-sync = {
    Unit.Description = "Periodic password-store sync";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
