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
    expectedSkills = config.universe.doctor.expectedSkills;
    forbiddenSkills = config.universe.doctor.forbiddenSkills;
    skillLedger = config.universe.doctor.skillLedger;
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

    expectedSkills = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Skill directory names that must be discoverable by every harness.";
    };

    forbiddenSkills = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Skill directory names that must not exist in any harness discovery root.";
    };

    skillLedger = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Home-relative path of the ledger naming the skills Universe managed on the last successful sync; its contents must equal expectedSkills.";
    };
  };

  config.xdg.configFile."universe/doctor.json".text = builtins.toJSON manifest;
}
