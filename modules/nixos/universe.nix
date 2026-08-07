{ lib, ... }:
{
  options.universe = {
    capabilities.ambientLight = lib.mkEnableOption "ambient-light-driven display brightness";
    roles.zenProfileWriter = lib.mkEnableOption "the single Zen profile writer role";
  };
}
