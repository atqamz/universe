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
    ];
    text = ''
      cfg="$HOME/.claude.json"
      tmp=$(mktemp)
      if [ -f "$cfg" ]; then
        jq '.mcpServers.codedb = {command: $bin, args: ["mcp"]}' --arg bin "${bin}" "$cfg" > "$tmp" || { rm -f "$tmp"; exit 1; }
      else
        jq -n --arg bin "${bin}" '{mcpServers: {codedb: {command: $bin, args: ["mcp"]}}}' > "$tmp" || { rm -f "$tmp"; exit 1; }
      fi
      mv "$tmp" "$cfg"
    '';
  };
in
{
  home.activation.codedbRegister = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${ensure}/bin/codedb-register
  '';

  systemd.user.services.codedb-register = {
    Unit.Description = "Register codedb MCP server for Claude Code";
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
