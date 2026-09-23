{ lib, ... }:
{
  options.universe.doctor = {
    activeSystemServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "System services that must be active for the host to be healthy.";
    };

    systemTimers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "System timers that must be enabled and active for the host to be healthy.";
    };
  };
}
