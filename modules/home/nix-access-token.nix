{ config, pkgs, ... }:
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

  services.userTimers.nix-access-token = {
    description = "Write the GitHub token nix reads for flake fetches";
    timerDescription = "Refresh nix's GitHub token";
    command = "${writeToken}/bin/nix-access-token-write";
    onActivation = "try";
    timer = {
      OnStartupSec = "30s";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
  };
}
