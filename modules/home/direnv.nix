{ config, ... }:
{
  home.file.".config/direnv/direnv.toml".text = ''
    [whitelist]
    prefix = ["${config.home.homeDirectory}/.treehouse"]
  '';
}
