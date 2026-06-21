{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  claudePkg = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;

  nodeShim = pkgs.writeShellScriptBin "node" ''exec ${pkgs.bun}/bin/bun "$@"'';

  marketplaces = {
    caveman = "JuliusBrussee/caveman";
    ponytail = "DietrichGebert/ponytail";
  };

  plugins = [
    "gopls-lsp@claude-plugins-official"
    "rust-analyzer-lsp@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "caveman@caveman"
    "ponytail@ponytail"
  ];

  impeccableRepo = "https://github.com/pbakaus/impeccable.git";
  impeccableCache = "$HOME/.cache/claude-skills/impeccable";
  impeccableSkill = "$HOME/.claude/skills/impeccable";

  runtime = with pkgs; [
    claudePkg
    bun
    nodeShim
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

  ensure = pkgs.writeShellApplication {
    name = "claude-plugins-ensure";
    runtimeInputs = runtime;
    text = ''
      log() { printf '==> claude-plugins: %s\n' "$*" >&2; }
      kmkt="$HOME/.claude/plugins/known_marketplaces.json"
      inst="$HOME/.claude/plugins/installed_plugins.json"

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

  refresh = pkgs.writeShellApplication {
    name = "claude-plugins-update";
    runtimeInputs = runtime;
    text = ''
      log() { logger -t claude-plugins -- "$*"; printf '==> %s\n' "$*"; }

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
  home.packages = [ nodeShim ];

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
