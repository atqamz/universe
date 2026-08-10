{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.universe.aiHarness;

  serverType = lib.types.submodule {
    options = {
      command = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to the stdio MCP server executable.";
      };

      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments passed to the server.";
      };

      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment forced on every harness instance of the server.";
      };
    };
  };

  bare = lib.mapAttrs (_: server: { inherit (server) command args env; }) cfg.mcpServers;

  claudeServers = lib.mapAttrs (_: server: { type = "stdio"; } // server) bare;

  codexPatch = lib.recursiveUpdate { mcp_servers = bare; } cfg.codexConfig;

  claudeJson = pkgs.writeText "claude-mcp-servers.json" (builtins.toJSON claudeServers);
  codexJson = pkgs.writeText "codex-config-patch.json" (builtins.toJSON codexPatch);

  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);

  tomlMerge = pkgs.writeText "codex-config-merge.py" ''
    import json
    import os
    import sys
    import tempfile

    import tomlkit

    target = sys.argv[1]
    patch_path = sys.argv[2]
    owned = sys.argv[3:]

    with open(patch_path) as handle:
        patch = json.load(handle)

    if os.path.isfile(target):
        with open(target) as handle:
            document = tomlkit.parse(handle.read())
    else:
        document = tomlkit.document()


    def resolve(node, path):
        for key in path:
            child = node.get(key)
            if not isinstance(child, dict):
                return None
            node = child
        return node


    def merge(node, value):
        for key, item in value.items():
            if isinstance(item, dict):
                if not isinstance(node.get(key), dict):
                    node[key] = tomlkit.table()
                merge(node[key], item)
            else:
                node[key] = item


    for dotted in owned:
        path = dotted.split(".")
        parent = resolve(document, path[:-1])
        if parent is not None and path[-1] in parent:
            del parent[path[-1]]

    merge(document, patch)

    directory = os.path.dirname(target) or "."
    os.makedirs(directory, exist_ok=True)
    descriptor, staging = tempfile.mkstemp(dir=directory)
    with os.fdopen(descriptor, "w") as out:
        out.write(tomlkit.dumps(document))
    os.replace(staging, target)
  '';

  reconcile = pkgs.writeShellApplication {
    name = "ai-harness-reconcile";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      python
    ];
    text = ''
      claude="$HOME/.claude.json"
      if [ -e "$claude" ] && ! jq -e . "$claude" >/dev/null 2>&1; then
        echo "ai-harness-reconcile: $claude is not valid JSON; refusing to rewrite it" >&2
        exit 1
      fi
      if [ ! -e "$claude" ]; then
        echo '{}' >"$claude"
      fi
      staging="$(mktemp "$claude.XXXXXX")"
      trap 'rm -f "$staging"' EXIT
      jq --slurpfile desired ${claudeJson} '.mcpServers = $desired[0]' "$claude" >"$staging"
      mv "$staging" "$claude"
      trap - EXIT

      mkdir -p "$HOME/.codex"
      python3 ${tomlMerge} "$HOME/.codex/config.toml" ${codexJson} mcp_servers
    '';
  };
in
{
  options.universe.aiHarness = {
    mcpServers = lib.mkOption {
      type = lib.types.attrsOf serverType;
      default = { };
      description = "MCP servers registered identically into Claude Code, Codex, and OpenCode.";
    };

    codexConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Codex config.toml keys owned by Universe and merged into the live file.";
    };
  };

  config = {
    home.packages = [ reconcile ];

    services.userTimers.ai-harness-reconcile = {
      description = "Reconcile AI harness MCP registration and Codex feature flags";
      timerDescription = "Boot-time AI harness registration reconcile";
      command = "${reconcile}/bin/ai-harness-reconcile";
      onActivation = "try";
      timer = {
        OnStartupSec = "1min";
        Persistent = false;
      };
    };

    universe.doctor = {
      commands = [
        "claude"
        "codex"
        "opencode"
      ];
      mcpServers = bare;
    };
  };
}
