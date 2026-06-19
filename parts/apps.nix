_: {
  perSystem =
    { pkgs, ... }:
    let
      vault = "$HOME/vault";
      rt = with pkgs; [
        git
        gh
        gnupg
        sops
        age
        coreutils
      ];

      export = pkgs.writeShellApplication {
        name = "secrets-export";
        runtimeInputs = rt;
        text = ''
          vault="${vault}"
          cd "$vault" || exit 1
          ./scripts/export.sh
          git add -A
          if git diff --cached --quiet; then
            echo "nothing to export"
            exit 0
          fi
          git commit -m "export live secrets"
          git push
        '';
      };

      bootstrap = pkgs.writeShellApplication {
        name = "secrets-bootstrap";
        runtimeInputs = rt;
        text = ''
          vault="${vault}"
          # Clone/pull the private vault over ssh with the sops-provisioned
          # read-only deploy key, so no interactive gh auth is needed on a fresh
          # machine. Falls back to gh if the key is absent (e.g. non-NixOS host).
          key=/run/secrets/vault-deploy-key
          if [ -r "$key" ]; then
            export GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
            remote="git@github.com:atqamz/vault.git"
          else
            remote=""
          fi
          if [ ! -d "$vault/.git" ]; then
            echo "==> cloning vault"
            mkdir -p "$(dirname "$vault")"
            if [ -n "$remote" ]; then
              git clone "$remote" "$vault"
            else
              gh repo clone atqamz/vault "$vault"
            fi
          else
            echo "==> updating vault"
            git -C "$vault" pull --ff-only
          fi
          cd "$vault" || exit 1
          ./scripts/import.sh
        '';
      };

      brainBootstrap = pkgs.writeShellApplication {
        name = "brain-bootstrap";
        runtimeInputs = rt;
        text = ''
          # Clone over ssh using the gpg-agent auth key (registered on GitHub),
          # so no interactive gh auth is needed. Pin SSH_AUTH_SOCK to gpg-agent
          # since an ssh-in session would otherwise inherit sshd's agent.
          SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
          export SSH_AUTH_SOCK
          export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
          for repo in dotai brain; do
            dest="$HOME/$repo"
            if [ ! -d "$dest/.git" ]; then
              echo "==> cloning $repo"
              git clone "git@github.com:atqamz/$repo.git" "$dest"
            else
              echo "==> updating $repo"
              git -C "$dest" pull --ff-only
            fi
          done
          if command -v qmd >/dev/null 2>&1; then
            echo "==> building brain index (qmd)"
            qmd collection add "$HOME/brain" --name brain 2>/dev/null || true
            qmd embed
          else
            echo "==> qmd not installed; skipping index build (grep recall still works)"
          fi
        '';
      };

      bootstrapCheck = pkgs.writeShellApplication {
        name = "bootstrap-check";
        runtimeInputs = with pkgs; [
          bash
          coreutils
          curl
          git
          gh
          gnupg
          jq
          openssh
          systemd
          tailscale
          gawk
        ];
        text = ''
          set -euo pipefail

          pass=0
          fail=0
          results=""

          check() {
            name="$1"
            shift
            if "$@" >/dev/null 2>&1; then
              echo "PASS: $name"
              pass=$((pass + 1))
              results="$results\nPASS: $name"
            else
              echo "FAIL: $name"
              fail=$((fail + 1))
              results="$results\nFAIL: $name"
            fi
          }

          echo "== bootstrap-check =="

          check "user atqa exists" id -u atqa
          check "user atqa is in wheel" groups atqa | grep -q wheel
          check "tailscale daemon running" systemctl is-active tailscaled
          check "tailscale up" tailscale status
          check "ssh daemon active" systemctl is-active sshd
          # ssh -T to github exits non-zero even on success (no shell), so match
          # the success banner instead of the exit code.
          # shellcheck disable=SC2016
          check "github ssh auth" bash -c 'SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket) ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"'
          check "secrets vault cloned" test -d "$HOME/vault/.git"
          check "ssh key present" test -f "$HOME/.ssh/id_ed25519.pub"
          check "gpg key present" gpg -K
          check "dotai cloned" test -d "$HOME/dotai/.git"
          check "brain cloned" test -d "$HOME/brain/.git"
          # shellcheck disable=SC2016
          check "brain on main" bash -c 'cd "$HOME/brain" && test "$(git rev-parse --abbrev-ref HEAD)" = main'
          check "brain qmd index exists" test -f "$HOME/.cache/qmd/index.sqlite"
          check "ollama service active" systemctl --user is-active ollama.service
          check "ollama api reachable" curl -fsS http://127.0.0.1:11434/api/tags
          check "brain-promote on PATH" command -v brain-promote
          check "brain-promote timer enabled" systemctl --user is-enabled brain-promote.timer
          check "brain-sync timer enabled" systemctl --user is-enabled brain-sync.timer
          check "secrets-sync timer enabled" systemctl --user is-enabled secrets-sync.timer
          check "flake-autoupdate timer enabled" systemctl --user is-enabled flake-autoupdate.timer
          check "universe repo cloned" test -d "$HOME/universe/.git"
          check "greetd active" systemctl is-active greetd
          check "claude-code on PATH" command -v claude

          echo ""
          echo "== summary =="
          echo "PASS: $pass"
          echo "FAIL: $fail"
          if [ "$fail" -eq 0 ]; then
            echo "bootstrap OK"
            exit 0
          else
            echo "bootstrap has failures"
            exit 1
          fi
        '';
      };
    in
    {
      apps = {
        secrets-export = {
          type = "app";
          program = "${export}/bin/secrets-export";
        };
        secrets-bootstrap = {
          type = "app";
          program = "${bootstrap}/bin/secrets-bootstrap";
        };
        brain-bootstrap = {
          type = "app";
          program = "${brainBootstrap}/bin/brain-bootstrap";
        };
        bootstrap-check = {
          type = "app";
          program = "${bootstrapCheck}/bin/bootstrap-check";
        };
      };
    };
}
