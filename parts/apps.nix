_: {
  perSystem =
    { pkgs, ... }:
    let
      vault = "$HOME/vault";
      opencodeProviderContract = import ../lib/opencode-provider-contract.nix;
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
              echo "==> keeping existing $repo checkout"
            fi
          done
        '';
      };

      doctor = pkgs.writeShellApplication {
        name = "universe-doctor";
        runtimeInputs = with pkgs; [
          bash
          coreutils
          diffutils
          git
          gnupg
          gnugrep
          jq
          openssh
          systemd
          tailscale
          codex
          opencode
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

          check_with_diagnostics() {
            local name="$1"
            shift
            local output

            if output="$("$@" 2>&1)"; then
              report "$name" 0
            else
              printf '%s\n' "$output" >&2
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

          # shellcheck disable=SC2329
          check_qmd_collection() {
            local name="$1"
            awk -v name="$name" '
              index($0, "  " name " (qmd://") == 1 { in_collection=1; next }
              in_collection && $0 ~ /^  [^ ]+ \(qmd:\/\// { in_collection=0 }
              in_collection && $0 ~ /^ +Files: +[1-9][0-9]*([[:space:]]|$)/ { found=1 }
              END { exit found ? 0 : 1 }
            ' "$probe/qmd.txt"
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
          # shellcheck disable=SC2016
          check "github https credential helper resolves" bash -c 'helper=$(git config --get "credential.https://github.com.helper") && bin=''${helper#!} && test -x "''${bin%% *}"'
          check "secrets vault cloned" test -d "$HOME/vault/.git"
          check "password store present" test -d "$HOME/.password-store"
          check "ssh key present" test -f "$HOME/.ssh/id_ed25519.pub"
          check "gpg key present" gpg -K
          check "dotagents cloned" test -d "$HOME/dotagents/.git"
          check "dotfiles cloned" test -d "$HOME/dotfiles/.git"
          check "universe repo cloned" test -d "$HOME/universe/.git"
          check "zen identity present" test -f "$HOME/.config/zen-profile/identity"
          check "greetd active" systemctl is-active greetd
          check "gw on PATH" command -v gw

          while IFS= read -r binary; do
            [ -n "$binary" ] || continue
            check "$binary on PATH" command -v "$binary"
          done < <(jq -r '.commands[]' "$manifest")

          while IFS= read -r relative; do
            [ -n "$relative" ] || continue
            check "$relative present" test -e "$HOME/$relative"
          done < <(jq -r '.paths[]' "$manifest")

          if jq -e '.noMistakes != null' "$manifest" >/dev/null; then
            no_mistakes_binary="$(jq -r '.noMistakes.binary' "$manifest")"
            no_mistakes_config="$(jq -r '.noMistakes.config' "$manifest")"
            no_mistakes_claude_settings="$(jq -r '.noMistakes.claudeSettings' "$manifest")"
            no_mistakes_reconcile="$(jq -r '.noMistakes.reconcile' "$manifest")"
            no_mistakes_skill_source="$(jq -r '.noMistakes.skillSource' "$manifest")"

            check "no-mistakes Nix binary exists" test -x "$no_mistakes_binary"
            # shellcheck disable=SC2016
            check "no-mistakes resolves to the Nix binary" bash -c 'actual=$(readlink -f "$(command -v no-mistakes)") && test "$actual" = "$1"' _ "$no_mistakes_binary"
            check_with_diagnostics "no-mistakes configuration is healthy" "$no_mistakes_reconcile" doctor

            while IFS= read -r agent; do
              [ -n "$agent" ] || continue
              check "no-mistakes agent $agent available" command -v "$agent"
            done < <(jq -r '.noMistakes.agents[]' "$manifest")

            check "no-mistakes daemon identity" "$no_mistakes_reconcile" check

            while IFS= read -r skill; do
              [ -n "$skill" ] || continue
              check "no-mistakes skill $skill present" test -f "$HOME/$skill"
              check "no-mistakes skill $skill is current" cmp -s "$HOME/$skill" "$no_mistakes_skill_source"
            done < <(jq -r '.noMistakes.skills[]' "$manifest")

            while IFS= read -r harness; do
              [ -n "$harness" ] || continue
              check_with_diagnostics "no-mistakes visible to $harness" "$no_mistakes_reconcile" discover "$harness" "$HOME/$no_mistakes_claude_settings"
            done < <(jq -r '.noMistakes.harnesses[]' "$manifest")

            check "no-mistakes config link target exists" test -e "$HOME/$no_mistakes_config"
          fi

          while IFS= read -r relative; do
            [ -n "$relative" ] || continue
            # shellcheck disable=SC2016
            check "$relative removed" bash -c '! test -e "$1" && ! test -L "$1"' _ "$HOME/$relative"
          done < <(jq -r '.absentPaths[]' "$manifest")

          probe="$(mktemp -d)"
          trap 'rm -rf "$probe"' EXIT

          opencode_config_status=0
          opencode debug config >"$probe/opencode-config.json" 2>/dev/null || opencode_config_status=$?
          opencode debug skill >"$probe/opencode-skills.txt" 2>/dev/null || true
          codex mcp list --json >"$probe/codex-mcp.json" 2>/dev/null || true
          herdr integration status >"$probe/herdr.txt" 2>/dev/null || true
          qmd status >"$probe/qmd.txt" 2>/dev/null || true

          check "opencode config command succeeds" test "$opencode_config_status" -eq 0
          check "opencode config loads" jq -e . "$probe/opencode-config.json"

          while IFS=$'\t' read -r provider npm base_url require_models; do
            [ -n "$provider" ] || continue
            # shellcheck disable=SC2016
            check "$provider provider resolves" jq -e \
              --arg p "$provider" --arg n "$npm" --arg u "$base_url" \
              '${opencodeProviderContract.provider}' \
              "$probe/opencode-config.json"
            if [ "$require_models" = true ]; then
              # shellcheck disable=SC2016
              check "$provider has runtime models" jq -e \
                --arg p "$provider" \
                '${opencodeProviderContract.models}' \
                "$probe/opencode-config.json"
            fi
          done < <(jq -r '.opencodeProviders | to_entries[] | [.key, .value.npm, .value.baseURL, (.value.requireModels | tostring)] | @tsv' "$manifest")

          while IFS= read -r server; do
            [ -n "$server" ] || continue
            desired="$(jq -c --arg s "$server" '.mcpServers[$s]' "$manifest")"

            # shellcheck disable=SC2016
            check "$server MCP registered for claude" jq -e \
              --arg s "$server" --argjson d "$desired" \
              '.mcpServers[$s] | .command == $d.command and .args == $d.args and (.env // {}) == $d.env' \
              "$HOME/.claude.json"

            # shellcheck disable=SC2016
            check "$server MCP registered for codex" jq -e \
              --arg s "$server" --argjson d "$desired" \
              'map(select(.name == $s)) | first | .enabled == true and (.transport | .command == $d.command and .args == $d.args and (.env // {}) == $d.env)' \
              "$probe/codex-mcp.json"

            # shellcheck disable=SC2016
            check "$server MCP registered for opencode" jq -e \
              --arg s "$server" --argjson d "$desired" \
              '.mcp[$s] | .type == "local" and .enabled == true and .command == ([$d.command] + $d.args) and (.environment // {}) == $d.env' \
              "$probe/opencode-config.json"
          done < <(jq -r '.mcpServers | keys[]' "$manifest")

          if jq -e '.mcpServers.codedb' "$manifest" >/dev/null; then
            # shellcheck disable=SC2016
            check "no stale codedb indexes" bash -c 'codedb-prune --dry-run | grep -q "no stale indexes"'
          fi

          while IFS= read -r name; do
            [ -n "$name" ] || continue
            check "qmd required collection $name loaded with documents" check_qmd_collection "$name"
          done < <(jq -r '.qmdRequiredCollections[]' "$manifest")

          if jq -e '.qmdCollections | length > 0' "$manifest" >/dev/null; then
            check "qmd config parses" test -s "$probe/qmd.txt"
            check "qmd has documents indexed" grep -qE "Total: +[1-9][0-9]* files indexed" "$probe/qmd.txt"
          fi

          while IFS= read -r target; do
            [ -n "$target" ] || continue
            check "herdr $target integration current" grep -qE "^$target: current " "$probe/herdr.txt"
          done < <(jq -r '.herdrIntegrations[]' "$manifest")

          ledger="$(jq -r '.skillLedger' "$manifest")"
          if [ -n "$ledger" ] && [ "$ledger" != null ]; then
            jq -r '.expectedSkills[]' "$manifest" | sort >"$probe/expected-skills"
            # shellcheck disable=SC2016
            check "universe managed skill ledger matches the allowlist" bash -c \
              'sort -- "$1" | diff -q - "$2"' _ "$HOME/$ledger" "$probe/expected-skills"
          fi

          while IFS= read -r skill; do
            [ -n "$skill" ] || continue
            check "skill $skill discoverable by claude" test -e "$HOME/.claude/skills/$skill/SKILL.md"
            check "skill $skill discoverable by codex" test -e "$HOME/.codex/skills/$skill/SKILL.md"
            check "skill $skill discoverable by opencode" grep -qF "$skill" "$probe/opencode-skills.txt"
          done < <(jq -r '.expectedSkills[]' "$manifest")

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
      };

      checks = {
        app-bootstrap = bootstrap;
        app-doctor = doctor;
        app-secrets-export = export;
      };
    };
}
