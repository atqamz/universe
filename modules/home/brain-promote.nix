{ pkgs, ... }:
let
  brain = "$HOME/brain";

  ollamaConfig = pkgs.writeShellApplication {
    name = "ollama-ensure-config";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      mkdir -p "$HOME/.ollama"
      if [ ! -f "$HOME/.ollama/config.json" ]; then
        cat > "$HOME/.ollama/config.json" <<'JSON'
      {
        "integrations": {
          "claude": {
            "models": [
              "kimi-k2.7-code:cloud"
            ]
          }
        }
      }
      JSON
      fi
    '';
  };

  promote = pkgs.writeShellApplication {
    name = "brain-promote";
    runtimeInputs = with pkgs; [
      git
      gh
      python3
      curl
      libnotify
    ];
    text = ''
      brain="${brain}"
      if [ ! -d "$brain/.git" ]; then
        echo "brain not bootstrapped; run: nix run .#brain-bootstrap" >&2
        exit 0
      fi

      # Daily promotion must start from a clean main worktree.
      current=$(git -C "$brain" rev-parse --abbrev-ref HEAD)
      if [ "$current" != "main" ]; then
        notify-send "brain-promote" "brain not on main ($current) — skipping" || true
        exit 0
      fi
      if [ -n "$(git -C "$brain" status --porcelain)" ]; then
        notify-send "brain-promote" "brain worktree dirty — skipping" || true
        exit 0
      fi

      exec "$HOME/.claude/bin/brain-promote"
    '';
  };
in
{
  home.packages = [
    promote
    pkgs.ollama
  ];

  systemd = {
    user = {
      services = {
        ollama = {
          Unit.Description = "Local Ollama server for Claude cloud models";
          Service = {
            Type = "simple";
            ExecStartPre = "${ollamaConfig}/bin/ollama-ensure-config";
            ExecStart = "${pkgs.ollama}/bin/ollama serve";
            Restart = "on-failure";
            Environment = [ "OLLAMA_HOST=127.0.0.1:11434" ];
          };
          Install.WantedBy = [ "default.target" ];
        };

        brain-promote = {
          Unit = {
            Description = "Promote brain log digests to note PR via LLM classifier";
            After = [ "ollama.service" ];
            Wants = [ "ollama.service" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${promote}/bin/brain-promote";
          };
        };
      };

      timers.brain-promote = {
        Unit.Description = "Daily brain promotion";
        Timer = {
          OnCalendar = "04:00";
          Persistent = true;
          RandomizedDelaySec = "15min";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
