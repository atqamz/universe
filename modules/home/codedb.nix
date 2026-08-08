{ pkgs, config, ... }:
let
  bin = "${config.home.profileDirectory}/bin/codedb";

  ensure = pkgs.writeShellApplication {
    name = "codedb-register";
    runtimeInputs = [
      pkgs.codedb
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      claudeCfg="$HOME/.claude.json"
      mkdir -p "$(dirname "$claudeCfg")"
      tmp="$(mktemp "$(dirname "$claudeCfg")/.claude.json.XXXXXX")"
      trap 'rm -f "$tmp"' EXIT
      if [ -f "$claudeCfg" ]; then
        jq '.mcpServers.codedb = {command: $bin, args: ["mcp"]}' --arg bin "${bin}" "$claudeCfg" >"$tmp"
      else
        jq -n --arg bin "${bin}" '{mcpServers: {codedb: {command: $bin, args: ["mcp"]}}}' >"$tmp"
      fi
      mv "$tmp" "$claudeCfg"
      trap - EXIT
    '';
  };
in
{
  services.userTimers.codedb-register = {
    description = "Register codedb MCP server for Claude Code";
    timerDescription = "Daily codedb MCP registration refresh";
    command = "${ensure}/bin/codedb-register";
    onActivation = "try";
    timer = {
      OnStartupSec = "10min";
      OnCalendar = "daily";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };
}
