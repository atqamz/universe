{ pkgs, config, ... }:
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
    '';
  };
in
{
  services.userTimers.codedb-register = {
    description = "Register codedb MCP server for Claude Code";
    timerDescription = "Daily codedb MCP registration refresh";
    command = "${ensure}/bin/codedb-register";
    onActivation = "run";
    timer = {
      OnStartupSec = "10min";
      OnCalendar = "daily";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };
}
