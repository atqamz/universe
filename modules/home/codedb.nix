{
  config,
  pkgs,
  ...
}:
let
  bin = "${config.home.profileDirectory}/bin/codedb";

  prune = pkgs.writeShellApplication {
    name = "codedb-prune";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = builtins.readFile ./codedb-prune.sh;
  };
in
{
  home.packages = [ prune ];

  home.sessionVariables = {
    CODEDB_NO_AUTO_UPDATE = "1";
    CODEDB_NO_CODEX_POLICY = "1";
  };

  universe.aiHarness.mcpServers.codedb = {
    command = bin;
    args = [ "mcp" ];
    env = {
      CODEDB_NO_AUTO_UPDATE = "1";
      CODEDB_NO_CODEX_POLICY = "1";
    };
  };

  services.userTimers.codedb-prune = {
    description = "Delete codedb indexes whose project root no longer exists";
    timerDescription = "Hourly codedb stale index prune";
    command = "${prune}/bin/codedb-prune";
    timer = {
      OnStartupSec = "15min";
      OnCalendar = "hourly";
      RandomizedDelaySec = "10min";
      Persistent = true;
    };
  };

  universe.doctor = {
    commands = [ "codedb" ];
    absentPaths = [ "bin/codedb" ];
  };
}
