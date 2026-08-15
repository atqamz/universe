{
  config,
  lib,
  osConfig,
  ...
}:
let
  wantedBy = unit: (unit.Install or { }).WantedBy or [ ];
  installed = units: lib.attrNames (lib.filterAttrs (_: unit: wantedBy unit != [ ]) units);
  manifest = {
    host = osConfig.networking.hostName;
    zenProfileWriter = osConfig.universe.roles.zenProfileWriter;
    timers = installed config.systemd.user.timers;
    services = installed config.systemd.user.services;
    activeSystemServices = osConfig.universe.doctor.activeSystemServices;
    activeUserServices = config.universe.doctor.activeUserServices;
    systemTimers = osConfig.universe.doctor.systemTimers;
    symlinks = config.universe.doctor.symlinks;
    commands = config.universe.doctor.commands;
    paths = config.universe.doctor.paths;
    absentPaths = config.universe.doctor.absentPaths;
    mcpServers = config.universe.doctor.mcpServers;
    herdrIntegrations = config.universe.doctor.herdrIntegrations;
    qmdCollections = config.universe.doctor.qmdCollections;
    qmdRequiredCollections = config.universe.doctor.qmdRequiredCollections;
    expectedSkills = config.universe.doctor.expectedSkills;
    skillLedger = config.universe.doctor.skillLedger;
    noMistakes = config.universe.doctor.noMistakes;
  };
in
{
  options.universe.doctor = {
    activeUserServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Installed user services that must also be active for the host to be healthy.";
    };

    symlinks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Home-relative symlink contracts checked by universe-doctor: both direct writable links that bypass the Home Manager store hop and read-only live instruction links.";
    };

    commands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Executables that must resolve on the interactive PATH.";
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Home-relative paths that must exist.";
    };

    absentPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Home-relative paths that must not exist because a declarative owner replaced them.";
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "MCP servers that must be registered identically in every harness, with their owning command, args, and env.";
    };

    herdrIntegrations = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Herdr integration targets whose installed asset version must equal the pinned expected version.";
    };

    qmdCollections = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "qmd collection name to indexed absolute source path.";
    };

    qmdRequiredCollections = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "qmd collections whose sources and indexed state are required for workstation health.";
    };

    expectedSkills = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Skill directory names that must be discoverable by every harness.";
    };

    skillLedger = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Home-relative path of the ledger naming the skills Universe managed on the last successful sync; its contents must equal expectedSkills.";
    };

    noMistakes = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            binary = lib.mkOption {
              type = lib.types.str;
              description = "Absolute Nix-owned no-mistakes executable path.";
            };

            config = lib.mkOption {
              type = lib.types.str;
              description = "Home-relative no-mistakes global configuration path.";
            };

            claudeSettings = lib.mkOption {
              type = lib.types.str;
              description = "Home-relative Claude user settings path whose no-mistakes skill visibility is checked.";
            };

            reconcile = lib.mkOption {
              type = lib.types.str;
              description = "Absolute no-mistakes reconciliation executable path.";
            };

            agents = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Native agents required by the workstation's global no-mistakes policy.";
            };

            harnesses = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Interactive harnesses that must discover the pinned no-mistakes skill.";
            };

            skillSource = lib.mkOption {
              type = lib.types.str;
              description = "Absolute pinned package path for the generated no-mistakes skill.";
            };

            skills = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Home-relative global no-mistakes skill paths that must match skillSource.";
            };
          };
        }
      );
      default = null;
      description = "Runtime contract for the Nix-owned no-mistakes integration.";
    };
  };

  config.xdg.configFile."universe/doctor.json".text = builtins.toJSON manifest;
}
