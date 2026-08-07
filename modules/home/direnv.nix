{ config, ... }:
{
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
    config.whitelist.prefix = [ "${config.home.homeDirectory}/.treehouse" ];
  };
}
