_: {
  imports = [
    ./dotagents.nix
    ./repo-pull-sync.nix
  ];

  home = {
    username = "atqa";
    homeDirectory = "/home/atqa";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;

  programs.bash.initExtra = ''
    nix() {
      local token nix_config
      if ! token="$(gh auth token 2>/dev/null)" || [[ -z "$token" ]]; then
        printf '%s\n' "nix: gh authentication unavailable" >&2
        return 1
      fi
      nix_config="access-tokens = github.com=$token"
      if [[ -n "''${NIX_CONFIG:-}" ]]; then
        nix_config+=$'\n'"$NIX_CONFIG"
      fi
      NIX_CONFIG="$nix_config" command nix "$@"
    }
  '';
}
