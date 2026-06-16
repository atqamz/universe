{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # Use the nix-provided claude so the timer/activation never depend on the
  # ~/.local self-updater being on PATH. Plugin state lives in ~/.claude/plugins
  # regardless of which binary writes it, so both stay in sync.
  claudePkg = inputs.claude-code.packages.${pkgs.system}.default;

  # Non-default marketplaces to register (official one is built in). Keep in
  # sync with extraKnownMarketplaces in dotai/claude/settings.json.
  marketplaces = {
    caveman = "JuliusBrussee/caveman";
    ponytail = "DietrichGebert/ponytail";
  };

  # Plugins we want present and auto-updated. enabledPlugins (in dotai
  # settings.json) flips them on; this list ensures they are installed + fresh.
  plugins = [
    "gopls-lsp@claude-plugins-official"
    "rust-analyzer-lsp@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "caveman@caveman"
    "ponytail@ponytail"
  ];

  # impeccable is a skill (not a plugin): a plain dir under ~/.claude/skills.
  # We track a checkout in cache and symlink its skill/ subdir into place; the
  # timer git-pulls it to keep it fresh.
  impeccableRepo = "https://github.com/pbakaus/impeccable.git";
  impeccableCache = "$HOME/.cache/claude-skills/impeccable";
  impeccableSkill = "$HOME/.claude/skills/impeccable";

  runtime = with pkgs; [
    claudePkg
    nodejs_22
    git
    coreutils
    gnugrep
  ];

  mktAddLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: repo: ''
      if ! grep -q '"${name}"' "$kmkt" 2>/dev/null; then
        log "marketplace add ${name} (${repo})"
        claude plugin marketplace add "${repo}" || log "  add ${name} failed"
      fi
    '') marketplaces
  );

  pluginInstallLines = lib.concatStringsSep "\n" (
    map (p: ''
      if ! grep -q '"${p}"' "$inst" 2>/dev/null; then
        log "install ${p}"
        claude plugin install "${p}" || log "  install ${p} failed"
      fi
    '') plugins
  );

  pluginUpdateLines = lib.concatStringsSep "\n" (
    map (p: ''claude plugin update "${p}" || log "  update ${p} failed"'') plugins
  );

  # Idempotent ensure-present: runs on every activation, best-effort, never
  # blocks the switch (all paths swallow failures).
  ensure = pkgs.writeShellApplication {
    name = "claude-plugins-ensure";
    runtimeInputs = runtime;
    text = ''
      log() { printf '==> claude-plugins: %s\n' "$*" >&2; }
      kmkt="$HOME/.claude/plugins/known_marketplaces.json"
      inst="$HOME/.claude/plugins/installed_plugins.json"

      # claude shells out to git to add/refresh marketplaces; the user gitconfig
      # rewrites https->ssh (insteadOf), which needs an ssh key + pinentry that
      # an unattended activation/timer lacks. Neutralize it to stay on https.
      export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

      ${mktAddLines}

      ${pluginInstallLines}

      if [ ! -e "${impeccableSkill}" ]; then
        log "clone impeccable skill"
        if [ ! -d "${impeccableCache}/.git" ]; then
          mkdir -p "$(dirname "${impeccableCache}")"
          git clone --quiet "${impeccableRepo}" "${impeccableCache}" \
            || log "  impeccable clone failed"
        fi
        if [ -d "${impeccableCache}/skill" ]; then
          ln -sfn "${impeccableCache}/skill" "${impeccableSkill}"
        fi
      fi
    '';
  };

  # Refresh marketplaces, plugins, and the impeccable checkout.
  refresh = pkgs.writeShellApplication {
    name = "claude-plugins-update";
    runtimeInputs = runtime;
    text = ''
      log() { logger -t claude-plugins -- "$*"; printf '==> %s\n' "$*"; }

      # See the ensure script: keep claude's git on https, not the ssh rewrite.
      export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

      claude plugin marketplace update || log "marketplace update failed"
      ${pluginUpdateLines}

      if [ -d "${impeccableCache}/.git" ]; then
        git -C "${impeccableCache}" pull --quiet || log "impeccable pull failed"
      fi
    '';
  };
in
{
  # Self-heal on every rebuild; DAG after writeBoundary so ~/.claude exists.
  home.activation.claudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${ensure}/bin/claude-plugins-ensure || true
  '';

  systemd.user.services.claude-plugins-update = {
    Unit.Description = "Update Claude Code plugins, marketplaces, and skills";
    Service = {
      Type = "oneshot";
      ExecStart = "${refresh}/bin/claude-plugins-update";
    };
  };

  systemd.user.timers.claude-plugins-update = {
    Unit.Description = "Daily Claude Code plugin/skill auto-update";
    Timer = {
      OnStartupSec = "10min";
      OnCalendar = "daily";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
