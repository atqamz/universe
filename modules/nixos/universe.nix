{ lib, ... }:
{
  options.universe = {
    capabilities = {
      ambientLight = lib.mkEnableOption "ambient-light-driven display brightness";
      handFleet = lib.mkEnableOption "the hand agent fleet orchestrator running on this host";
      knowledgeCorpus = lib.mkEnableOption "the local documentation corpus that qmd collections index";
    };
    doctor = {
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
  };
}
