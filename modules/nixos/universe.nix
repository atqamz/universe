{ lib, ... }:
{
  options.universe = {
    capabilities = {
      ambientLight = lib.mkEnableOption "ambient-light-driven display brightness";
      knowledgeCorpus = lib.mkEnableOption "the local documentation corpus that qmd collections index";
    };
    roles.zenProfileWriter = lib.mkEnableOption "the single Zen profile writer role";

    doctor = {
      activeSystemServices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "System services that must be active for the host to be healthy.";
      };

      systemTimers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "System timers that must be enabled for the host to be healthy.";
      };
    };
  };
}
