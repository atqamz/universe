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

      project_root() {
        local marker="$1"
        local value

        [ -f "$marker" ] && [ -r "$marker" ] || return 1
        value="$(head -n 1 -- "$marker" 2>/dev/null)" || return 1
        case "$value" in
          /*) ;;
          *) return 1 ;;
        esac
        printf '%s\n' "$value"
      }

      stale=()
      unknown=0
      for index in "$root"/*; do
        [ -d "$index" ] || continue
        if ! project="$(project_root "$index/project.txt")"; then
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

      reclaimable="unknown size"
      if measured="$(du -shc -- "''${stale[@]}" 2>/dev/null | tail -n 1 | cut -f1)" \
        && [ -n "$measured" ]; then
        reclaimable="$measured"
      fi
      echo "codedb-prune: $count stale indexes, $reclaimable reclaimable"

      if [ "$dry" -eq 1 ]; then
        for index in "''${stale[@]}"; do
          printf '%s -> %s\n' "$index" "$(project_root "$index/project.txt" || echo '<marker unreadable>')"
        done
        exit 0
      fi

      removed=0
      kept=0
      for index in "''${stale[@]}"; do
        if ! project="$(project_root "$index/project.txt")"; then
          echo "codedb-prune: $index lost its project marker after the scan; left untouched"
          kept=$((kept + 1))
          continue
        fi
        if [ -e "$project" ]; then
          echo "codedb-prune: $project exists again; keeping $index"
          kept=$((kept + 1))
          continue
        fi
        rm -rf -- "$index"
        removed=$((removed + 1))
      done

      echo "codedb-prune: removed $removed of $count stale indexes, reclaimed up to $reclaimable"
      if [ "$kept" -gt 0 ]; then
        echo "codedb-prune: $kept indexes were no longer stale at deletion time; left untouched"
      fi
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
