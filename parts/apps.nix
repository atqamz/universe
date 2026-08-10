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

      aiCleanup = pkgs.writeShellApplication {
        name = "ai-stack-cleanup";
        runtimeInputs = with pkgs; [
          coreutils
          jq
        ];
        text = ''
          dry=0
          case "''${1-}" in
            --dry-run) dry=1 ;;
            "") ;;
            *)
              echo "usage: ai-stack-cleanup [--dry-run]" >&2
              exit 2
              ;;
          esac

          removed=0
          kept=0

          drop() {
            local reason="$1"
            local path="$2"

            case "$path" in
              */.agents/skills | */.claude/skills | */.codex/skills | */.config/opencode/skills \
                | */.claude/plugins | */.claude/plugins/cache | */.claude/plugins/marketplaces \
                | */.config/opencode/agents | */.config/opencode/commands)
                echo "refuse: $path is a harness discovery root, not migration residue" >&2
                exit 1
                ;;
            esac

            if [ ! -e "$path" ] && [ ! -L "$path" ]; then
              return 0
            fi
            if [ -L "$path" ] && readlink -- "$path" | grep -q '^/nix/store/'; then
              echo "keep: $path is a declaratively owned store link"
              kept=$((kept + 1))
              return 0
            fi

            local size measured
            if [ -L "$path" ] && [ ! -e "$path" ]; then
              size="dangling link"
            elif measured="$(du -shL -- "$path" 2>/dev/null | cut -f1)" && [ -n "$measured" ]; then
              size="$measured"
            else
              size="unknown size"
            fi
            echo "remove: $path ($size) - $reason"
            if [ "$dry" -eq 0 ]; then
              rm -rf -- "$path"
            fi
            removed=$((removed + 1))
          }

          prune_json() {
            local file="$1"
            local filter="$2"
            local what="$3"

            [ -f "$file" ] || return 0
            if ! jq -e "($filter) | length > 0" "$file" >/dev/null 2>&1; then
              return 0
            fi
            echo "remove: $what from $file"
            if [ "$dry" -eq 0 ]; then
              local staging
              staging="$(mktemp "$file.XXXXXX")"
              jq "delpaths($filter)" "$file" >"$staging"
              mv "$staging" "$file"
            fi
            removed=$((removed + 1))
          }

          echo "== superseded codedb payloads =="
          drop "codedb is Nix-owned; no self-updated copy may shadow it" "$HOME/bin/codedb"
          drop "codedb self-update is disabled" "$HOME/.codedb/last_auto_update_check"
          drop "codedb Codex policy injection is disabled" "$HOME/.codedb/codex-policy-registered"

          echo "== superseded RTK and Herdr artifacts =="
          drop "RTK instructions now live in dotagents/AGENTS.md" "$HOME/.claude/RTK.md"
          drop "editor backup of a Home Manager owned file" "$HOME/.codex/AGENTS.md.bak"
          drop "editor backup of a Home Manager owned file" "$HOME/.config/opencode/AGENTS.md.save"

          echo "== removed skill delivery =="
          for name in caveman caveman-commit caveman-compress caveman-help caveman-review \
            caveman-stats cavecrew ponytail ponytail-audit ponytail-debt ponytail-gain \
            ponytail-help ponytail-review; do
            drop "skill removed from the manifest" "$HOME/.agents/skills/$name"
            drop "skill removed from the manifest" "$HOME/.claude/skills/$name"
            drop "skill removed from the manifest" "$HOME/.codex/skills/$name"
          done
          for name in cavecrew-builder cavecrew-investigator cavecrew-reviewer; do
            drop "agent belonged to a removed skill" "$HOME/.config/opencode/agents/$name.md"
          done
          for name in caveman caveman-commit caveman-compress caveman-help caveman-review caveman-stats; do
            drop "command belonged to a removed skill" "$HOME/.config/opencode/commands/$name.md"
          done
          drop "runtime marker of a removed skill" "$HOME/.config/opencode/.caveman-active"

          echo "== duplicate and removed Claude plugins =="
          drop "plugin superseded by skills-sync" "$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
          for name in caveman ponytail; do
            drop "plugin marketplace of a removed skill" "$HOME/.claude/plugins/marketplaces/$name"
            drop "plugin cache of a removed skill" "$HOME/.claude/plugins/cache/$name"
          done
          prune_json "$HOME/.claude/plugins/installed_plugins.json" \
            '[(.plugins // {}) | keys[] | select(test("^(caveman|ponytail)")) | ["plugins", .]]' \
            "removed plugin registrations"
          prune_json "$HOME/.claude/plugins/installed_plugins.json" \
            '[(.plugins // {}) | keys[] | select(. == "superpowers@claude-plugins-official") | ["plugins", .]]' \
            "duplicate superpowers registration"
          prune_json "$HOME/.claude/plugins/known_marketplaces.json" \
            '[keys[] | select(. == "caveman" or . == "ponytail") | [.]]' \
            "removed plugin marketplaces"

          echo ""
          echo "== summary =="
          echo "removed: $removed"
          echo "kept: $kept"
          if [ "$dry" -eq 1 ]; then
            echo "dry run: nothing was deleted"
          fi
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

          while IFS= read -r relative; do
            [ -n "$relative" ] || continue
            # shellcheck disable=SC2016
            check "$relative removed" bash -c '! test -e "$1" && ! test -L "$1"' _ "$HOME/$relative"
          done < <(jq -r '.absentPaths[]' "$manifest")

          probe="$(mktemp -d)"
          trap 'rm -rf "$probe"' EXIT

          opencode debug config >"$probe/opencode-config.json" 2>/dev/null || true
          opencode debug skill >"$probe/opencode-skills.txt" 2>/dev/null || true
          codex mcp list --json >"$probe/codex-mcp.json" 2>/dev/null || true
          herdr integration status >"$probe/herdr.txt" 2>/dev/null || true
          qmd status >"$probe/qmd.txt" 2>/dev/null || true

          check "opencode config loads" jq -e . "$probe/opencode-config.json"

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

          while IFS=$'\t' read -r name path; do
            [ -n "$name" ] || continue
            check "qmd collection $name source present" test -d "$path"
            check "qmd collection $name loaded" grep -qE "^ +$name \(qmd://" "$probe/qmd.txt"
          done < <(jq -r '.qmdCollections | to_entries[] | [.key, .value] | @tsv' "$manifest")

          if jq -e '.qmdCollections | length > 0' "$manifest" >/dev/null; then
            check "qmd config parses" test -s "$probe/qmd.txt"
            check "qmd has documents indexed" grep -qE "Total: +[1-9][0-9]* files indexed" "$probe/qmd.txt"
          fi

          while IFS= read -r target; do
            [ -n "$target" ] || continue
            check "herdr $target integration current" grep -qE "^$target: current " "$probe/herdr.txt"
          done < <(jq -r '.herdrIntegrations[]' "$manifest")

          while IFS= read -r skill; do
            [ -n "$skill" ] || continue
            check "skill $skill discoverable by claude" test -e "$HOME/.claude/skills/$skill/SKILL.md"
            check "skill $skill discoverable by codex" test -e "$HOME/.codex/skills/$skill/SKILL.md"
            check "skill $skill discoverable by opencode" grep -qF "$skill" "$probe/opencode-skills.txt"
          done < <(jq -r '.expectedSkills[]' "$manifest")

          while IFS= read -r skill; do
            [ -n "$skill" ] || continue
            # shellcheck disable=SC2016
            check "skill $skill absent" bash -c \
              '! test -e "$HOME/.agents/skills/$1" && ! test -L "$HOME/.claude/skills/$1" && ! test -e "$HOME/.codex/skills/$1"' _ "$skill"
          done < <(jq -r '.forbiddenSkills[]' "$manifest")

          plugins="$HOME/.claude/plugins/installed_plugins.json"
          # shellcheck disable=SC2016
          check "no removed claude plugins registered" bash -c \
            '! test -f "$1" || ! jq -e ".plugins | keys[] | select(test(\"^(caveman|ponytail)\"))" "$1" >/dev/null 2>&1' _ "$plugins"
          # shellcheck disable=SC2016
          check "superpowers delivered only by skills-sync" bash -c \
            '! test -f "$1" || ! jq -e ".plugins | has(\"superpowers@claude-plugins-official\")" "$1" >/dev/null 2>&1' _ "$plugins"

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
        ai-stack-cleanup = {
          type = "app";
          program = "${aiCleanup}/bin/ai-stack-cleanup";
          meta.description = "Remove AI harness runtime residue superseded by declarative ownership";
        };
      };

      checks = {
        app-ai-stack-cleanup = aiCleanup;
        app-bootstrap = bootstrap;
        app-doctor = doctor;
        app-secrets-export = export;
      };
    };
}
