{
  config,
  pkgs,
  ...
}:
let
  bin = "${config.home.profileDirectory}/bin/codedb";

  prune = pkgs.writeShellApplication {
    name = "codedb-prune";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      root="''${CODEDB_HOME:-$HOME/.codedb}/projects"
      dry=0
      case "''${1-}" in
        --dry-run) dry=1 ;;
        "") ;;
        *)
          echo "usage: codedb-prune [--dry-run]" >&2
          exit 2
          ;;
      esac

      if [ ! -d "$root" ]; then
        echo "codedb-prune: no index directory at $root"
        exit 0
      fi

      stale=()
      unknown=0
      for index in "$root"/*; do
        [ -d "$index" ] || continue
        marker="$index/project.txt"
        if [ ! -f "$marker" ]; then
          unknown=$((unknown + 1))
          continue
        fi
        project="$(head -n 1 "$marker")"
        if [ -z "$project" ]; then
          unknown=$((unknown + 1))
          continue
        fi
        if [ -e "$project" ]; then
          continue
        fi
        stale+=("$index")
      done

      if [ "$unknown" -gt 0 ]; then
        echo "codedb-prune: $unknown index directories without a readable project root; left untouched"
      fi

      count=''${#stale[@]}
      if [ "$count" -eq 0 ]; then
        echo "codedb-prune: no stale indexes"
        exit 0
      fi

      reclaimable="$(du -shc -- "''${stale[@]}" | tail -n 1 | cut -f1)"
      echo "codedb-prune: $count stale indexes, $reclaimable reclaimable"

      if [ "$dry" -eq 1 ]; then
        for index in "''${stale[@]}"; do
          printf '%s -> %s\n' "$index" "$(head -n 1 "$index/project.txt")"
        done
        exit 0
      fi

      for index in "''${stale[@]}"; do
        rm -rf -- "$index"
      done
      echo "codedb-prune: removed $count stale indexes, reclaimed $reclaimable"
    '';
  };
in
{
  home.packages = [ prune ];

  home.sessionVariables = {
    CODEDB_NO_AUTO_UPDATE = "1";
    CODEDB_NO_CODEX_POLICY = "1";
  };

  universe.aiHarness.mcpServers.codedb = {
    command = bin;
    args = [ "mcp" ];
    env = {
      CODEDB_NO_AUTO_UPDATE = "1";
      CODEDB_NO_CODEX_POLICY = "1";
    };
  };

  services.userTimers.codedb-prune = {
    description = "Delete codedb indexes whose project root no longer exists";
    timerDescription = "Weekly codedb stale index prune";
    command = "${prune}/bin/codedb-prune";
    timer = {
      OnStartupSec = "15min";
      OnCalendar = "weekly";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };

  universe.doctor = {
    commands = [ "codedb" ];
    absentPaths = [ "bin/codedb" ];
  };
}
