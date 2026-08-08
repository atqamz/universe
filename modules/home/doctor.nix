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
      description = "Direct home-relative symlink contracts checked by universe-doctor.";
    };
  };

  config.xdg.configFile."universe/doctor.json".text = builtins.toJSON manifest;
}
