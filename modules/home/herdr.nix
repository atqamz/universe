{
  config,
  inputs,
  ...
}:
let
  assets = "${inputs.herdr}/src/integration/assets";

  codexHook = "${config.home.homeDirectory}/.codex/herdr-agent-state.sh";

  codexHooks = {
    hooks.SessionStart = [
      {
        hooks = [
          {
            type = "command";
            command = "bash '${codexHook}' session";
            timeout = 10;
          }
        ];
      }
    ];
  };
in
{
  home.file = {
    ".claude/hooks/herdr-agent-state.sh".source = "${assets}/claude/herdr-agent-state.sh";
    ".codex/herdr-agent-state.sh".source = "${assets}/codex/herdr-agent-state.sh";
    ".codex/hooks.json".text = builtins.toJSON codexHooks;
    ".config/opencode/plugins/herdr-agent-state.js".source = "${assets}/opencode/herdr-agent-state.js";
  };

  universe.aiHarness = {
    codexConfig.features.hooks = true;
    codexOwnedPaths = [ "features.hooks" ];
  };

  universe.doctor = {
    commands = [ "herdr" ];
    paths = [
      ".claude/hooks/herdr-agent-state.sh"
      ".codex/herdr-agent-state.sh"
      ".codex/hooks.json"
      ".config/opencode/plugins/herdr-agent-state.js"
    ];
    herdrIntegrations = [
      "claude"
      "codex"
      "opencode"
    ];
  };
}
