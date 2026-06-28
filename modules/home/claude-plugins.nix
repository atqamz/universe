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
    impeccable = "pbakaus/impeccable";
  };

  plugins = [
    "gopls-lsp@claude-plugins-official"
    "rust-analyzer-lsp@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "caveman@caveman"
    "ponytail@ponytail"
    "impeccable@impeccable"
  ];

  standaloneSkills = { };

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

  skillInstallLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: src: ''
      if [ ! -e "$HOME/.claude/skills/.managed-${name}" ]; then
        log "add skill ${name} (${src})"
        if bunx skills add "${src}" -g -a claude-code -y; then
          touch "$HOME/.claude/skills/.managed-${name}"
        else
          log "  add ${name} failed"
        fi
      fi
    '') standaloneSkills
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

      if [ -L "$HOME/.claude/skills/impeccable" ]; then
        log "migrate impeccable from git clone to skills CLI"
        rm -f "$HOME/.claude/skills/impeccable"
        rm -rf "$HOME/.cache/claude-skills/impeccable"
      fi

      mkdir -p "$HOME/.claude/skills"

      ${skillInstallLines}
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

      bunx skills update -g -y || log "skills update failed"
    '';
  };
in
{
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
