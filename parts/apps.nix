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
        name = "bootstrap";
        runtimeInputs = rt;
        text = ''
          vault="${vault}"

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
          ( cd "$vault" && ./scripts/import.sh )

          SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
          export SSH_AUTH_SOCK
          export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
          for repo in dotagents dotfiles; do
            dest="$HOME/$repo"
            if [ ! -d "$dest/.git" ]; then
              echo "==> cloning $repo"
              git clone "git@github.com:atqamz/$repo.git" "$dest"
            else
              echo "==> updating $repo"
              git -C "$dest" pull --ff-only
            fi
          done
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
          # shellcheck disable=SC2016
          check "github ssh auth" bash -c 'SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket) ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"'
          check "secrets vault cloned" test -d "$HOME/vault/.git"
          check "ssh key present" test -f "$HOME/.ssh/id_ed25519.pub"
          check "gpg key present" gpg -K
          check "dotagents cloned" test -d "$HOME/dotagents/.git"
          check "dotfiles cloned" test -d "$HOME/dotfiles/.git"
          check "dotfiles-sync timer enabled" systemctl --user is-enabled dotfiles-sync.timer
          check "dotagents-sync timer enabled" systemctl --user is-enabled dotagents-sync.timer
          check "vault-sync timer enabled" systemctl --user is-enabled vault-sync.timer
          check "password-store-sync timer enabled" systemctl --user is-enabled password-store-sync.timer
          check "nixos-upgrade timer enabled" systemctl is-enabled nixos-upgrade.timer
          check "zen identity present" test -f "$HOME/.config/zen-profile/identity"
          check "zen-profile-sync timer enabled" systemctl --user is-enabled zen-profile-sync.timer
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
        bootstrap = {
          type = "app";
          program = "${bootstrap}/bin/bootstrap";
        };
        bootstrap-check = {
          type = "app";
          program = "${bootstrapCheck}/bin/bootstrap-check";
        };
      };
    };
}
