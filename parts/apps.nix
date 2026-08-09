_: {
  perSystem =
    { pkgs, ... }:
    let
      vault = "$HOME/vault";
      secretsTools = with pkgs; [
        age
        coreutils
        gh
        git
        gnupg
        openssh
        sops
      ];

      export = pkgs.writeShellApplication {
        name = "secrets-export";
        runtimeInputs = secretsTools;
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
        runtimeInputs = secretsTools;
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

      doctor = pkgs.writeShellApplication {
        name = "universe-doctor";
        runtimeInputs = with pkgs; [
          bash
          coreutils
          git
          gnupg
          gnugrep
          jq
          openssh
          systemd
          tailscale
        ];
        text = ''
          manifest="$HOME/.config/universe/doctor.json"
          pass=0
          fail=0

          report() {
            local name="$1"
            local status="$2"

            if [ "$status" -eq 0 ]; then
              echo "PASS: $name"
              pass=$((pass + 1))
            else
              echo "FAIL: $name"
              fail=$((fail + 1))
            fi
          }

          check() {
            local name="$1"
            shift

            if "$@" >/dev/null 2>&1; then
              report "$name" 0
            else
              report "$name" 1
            fi
          }

          check_link() {
            local relative="$1"
            local target="$2"
            local path="$HOME/$relative"
            local expected="$HOME/$target"
            local actual
            local expected_real

            if [ -L "$path" ] \
              && [ -e "$expected" ] \
              && actual="$(readlink -f -- "$path" 2>/dev/null)" \
              && expected_real="$(readlink -f -- "$expected" 2>/dev/null)" \
              && [ "$actual" = "$expected_real" ]; then
              report "$relative direct symlink" 0
            else
              report "$relative direct symlink" 1
            fi
          }

          echo "== universe-doctor =="
          check "doctor manifest present" test -f "$manifest"
          if [ ! -f "$manifest" ]; then
            echo "doctor manifest missing; apply the full configuration first" >&2
            exit 1
          fi

          host="$(jq -r '.host' "$manifest")"
          echo "host: $host"

          check "user atqa exists" id -u atqa
          check "user atqa is in wheel" bash -c 'groups atqa | grep -q wheel'
          check "tailscale daemon running" systemctl is-active tailscaled
          check "tailscale up" tailscale status
          check "ssh daemon active" systemctl is-active sshd
          # shellcheck disable=SC2016
          check "github ssh auth" bash -c 'SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket) ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"'
          check "secrets vault cloned" test -d "$HOME/vault/.git"
          check "password store present" test -d "$HOME/.password-store"
          check "ssh key present" test -f "$HOME/.ssh/id_ed25519.pub"
          check "gpg key present" gpg -K
          check "dotagents cloned" test -d "$HOME/dotagents/.git"
          check "dotfiles cloned" test -d "$HOME/dotfiles/.git"
          check "universe repo cloned" test -d "$HOME/universe/.git"
          check "zen identity present" test -f "$HOME/.config/zen-profile/identity"
          check "greetd active" systemctl is-active greetd
          check "claude-code on PATH" command -v claude
          check "gw on PATH" command -v gw

          while IFS= read -r unit; do
            [ -n "$unit" ] || continue
            check "$unit.timer enabled" systemctl --user is-enabled "$unit.timer"
          done < <(jq -r '.timers[]' "$manifest")

          while IFS= read -r unit; do
            [ -n "$unit" ] || continue
            check "$unit.service enabled" systemctl --user is-enabled "$unit.service"
          done < <(jq -r '.services[]' "$manifest")

          while IFS= read -r unit; do
            [ -n "$unit" ] || continue
            check "$unit.service active" systemctl --user is-active "$unit.service"
          done < <(jq -r '.activeUserServices[]' "$manifest")

          while IFS= read -r unit; do
            [ -n "$unit" ] || continue
            check "$unit.service active" systemctl is-active "$unit.service"
          done < <(jq -r '.activeSystemServices[]' "$manifest")

          while IFS= read -r unit; do
            [ -n "$unit" ] || continue
            check "$unit.timer enabled" systemctl is-enabled "$unit.timer"
          done < <(jq -r '.systemTimers[]' "$manifest")

          while IFS=$'\t' read -r path target; do
            [ -n "$path" ] || continue
            check_link "$path" "$target"
          done < <(jq -r '.symlinks | to_entries[] | [.key, .value] | @tsv' "$manifest")

          if jq -e '.zenProfileWriter' "$manifest" >/dev/null; then
            check "zen-profile-push service available" systemctl --user cat zen-profile-push.service
          fi

          check "nixos-upgrade timer enabled" systemctl is-enabled nixos-upgrade.timer
          # shellcheck disable=SC2016
          check "nixos-upgrade not failed" bash -c '[ "$(systemctl is-failed nixos-upgrade.service)" != failed ]'
          # shellcheck disable=SC2016
          check "no failed system units" bash -c '[ -z "$(systemctl list-units --state=failed --no-legend)" ]'
          # shellcheck disable=SC2016
          check "no failed user units" bash -c '[ -z "$(systemctl --user list-units --state=failed --no-legend)" ]'

          echo ""
          echo "== summary =="
          echo "PASS: $pass"
          echo "FAIL: $fail"
          if [ "$fail" -eq 0 ]; then
            echo "universe healthy"
            exit 0
          fi
          echo "universe has failures"
          exit 1
        '';
      };
    in
    {
      apps = {
        secrets-export = {
          type = "app";
          program = "${export}/bin/secrets-export";
          meta.description = "Export live secrets back to the vault";
        };
        bootstrap = {
          type = "app";
          program = "${bootstrap}/bin/bootstrap";
          meta.description = "Bootstrap universe companion repositories and secrets";
        };
        doctor = {
          type = "app";
          program = "${doctor}/bin/universe-doctor";
          meta.description = "Verify declarative and live universe invariants";
        };
        bootstrap-check = {
          type = "app";
          program = "${doctor}/bin/universe-doctor";
          meta.description = "Compatibility alias for universe doctor";
        };
      };

      checks = {
        app-bootstrap = bootstrap;
        app-doctor = doctor;
        app-secrets-export = export;
      };
    };
}
