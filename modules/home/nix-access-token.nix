{
  config,
  pkgs,
  lib,
  ...
}:
let
  tokenFile = "${config.home.homeDirectory}/.config/nix/access-tokens.conf";

  writeToken = pkgs.writeShellApplication {
    name = "nix-access-token-write";
    runtimeInputs = with pkgs; [
      gh
      coreutils
    ];
    text = ''
      target="${tokenFile}"
      if ! token="$(gh auth token 2>/dev/null)" || [ -z "$token" ]; then
        echo "gh authentication unavailable; leaving $target as it is" >&2
        exit 0
      fi
      mkdir -p "$(dirname "$target")"
      umask 077
      printf 'access-tokens = github.com=%s\n' "$token" > "$target.tmp"
      mv "$target.tmp" "$target"
    '';
  };
in
{
  xdg.configFile."nix/nix.conf".text = ''
    !include ${tokenFile}
    tarball-ttl = 0
  '';

  home.activation.nixAccessToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${writeToken}/bin/nix-access-token-write || true
  '';

  systemd.user.services.nix-access-token = {
    Unit = {
      Description = "Write the GitHub token nix reads for flake fetches";
      OnFailure = [ "notify-failure@%n.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${writeToken}/bin/nix-access-token-write";
    };
  };

  systemd.user.timers.nix-access-token = {
    Unit.Description = "Refresh nix's GitHub token";
    Timer = {
      OnStartupSec = "30s";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
