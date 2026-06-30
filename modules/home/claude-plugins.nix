{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  claudePkg = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;

  nodeShim = pkgs.writeShellScriptBin "node" ''exec ${pkgs.bun}/bin/bun "$@"'';

  plugins = [
    "superpowers@claude-plugins-official"
    "caveman@caveman"
    "ponytail@ponytail"
  ];

  runtime = with pkgs; [
    claudePkg
    bun
    nodeShim
    git
    coreutils
  ];

  pluginUpdateLines = lib.concatStringsSep "\n" (
    map (p: ''claude plugin update "${p}" || log "  update ${p} failed"'') plugins
  );

  refresh = pkgs.writeShellApplication {
    name = "claude-plugins-update";
    runtimeInputs = runtime;
    text = ''
      log() { logger -t claude-plugins -- "$*"; printf '==> %s\n' "$*"; }

      export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

      claude plugin marketplace update || log "marketplace update failed"
      ${pluginUpdateLines}
    '';
  };
in
{
  systemd.user.services.claude-plugins-update = {
    Unit.Description = "Update Claude Code plugins and marketplaces";
    Service = {
      Type = "oneshot";
      ExecStart = "${refresh}/bin/claude-plugins-update";
    };
  };

  systemd.user.timers.claude-plugins-update = {
    Unit.Description = "Daily Claude Code plugin/marketplace auto-update";
    Timer = {
      OnStartupSec = "10min";
      OnCalendar = "daily";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
