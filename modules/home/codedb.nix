{
  pkgs,
  lib,
  config,
  ...
}:
let
  bin = "${config.home.profileDirectory}/bin/codedb";

  ensure = pkgs.writeShellApplication {
    name = "codedb-register";
    runtimeInputs = [
      pkgs.codedb
      pkgs.jq
      pkgs.gawk
    ];
    text = ''
      claudeCfg="$HOME/.claude.json"
      tmp=$(mktemp)
      if [ -f "$claudeCfg" ]; then
        jq '.mcpServers.codedb = {command: $bin, args: ["mcp"]}' --arg bin "${bin}" "$claudeCfg" > "$tmp" || { rm -f "$tmp"; exit 1; }
      else
        jq -n --arg bin "${bin}" '{mcpServers: {codedb: {command: $bin, args: ["mcp"]}}}' > "$tmp" || { rm -f "$tmp"; exit 1; }
      fi
      mv "$tmp" "$claudeCfg"

      codexCfg="$HOME/.codex/config.toml"
      if [ -f "$codexCfg" ]; then
        ctmp=$(mktemp)
        awk '
          /^\[mcp_servers\.codedb\]/ { skip=1; next }
          skip && /^\[/ { skip=0 }
          skip { next }
          { print }
        ' "$codexCfg" > "$ctmp"
        {
          echo ""
          echo "[mcp_servers.codedb]"
          echo "command = \"${bin}\""
          echo 'args = ["mcp"]'
          echo "startup_timeout_sec = 30"
        } >> "$ctmp"
        mv "$ctmp" "$codexCfg"
      fi
    '';
  };
in
{
  home.activation.codedbRegister = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${ensure}/bin/codedb-register
  '';

  systemd.user.services.codedb-register = {
    Unit.Description = "Register codedb MCP server for Claude Code and Codex";
    Service = {
      Type = "oneshot";
      ExecStart = "${ensure}/bin/codedb-register";
    };
  };

  systemd.user.timers.codedb-register = {
    Unit.Description = "Daily codedb MCP registration refresh";
    Timer = {
      OnStartupSec = "10min";
      OnCalendar = "daily";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
