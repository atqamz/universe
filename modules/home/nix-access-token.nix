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
  # Absolute, not relative: nix.conf is a store symlink, so a relative !include would
  # resolve against the store directory instead of ~/.config/nix.
  xdg.configFile."nix/nix.conf".text = ''
    !include ${tokenFile}
  '';

  home.activation.nixAccessToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${writeToken}/bin/nix-access-token-write || true
  '';

  systemd.user.services.nix-access-token = {
    Unit.Description = "Write the GitHub token nix reads for flake fetches";
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
