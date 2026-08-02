{ config, ... }:
{
  programs.git = {
    enable = true;
    settings.user = {
      name = "Atqa Munzir";
      email = "atqamz@gmail.com";
    };
    signing = {
      key = "8AD7D4A302EE6771";
      signByDefault = true;
    };
    includes = [
      {
        condition = "gitdir:${config.home.homeDirectory}/github/yes2games/";
        contents.user.email = "atqa@yes2games.com";
      }
    ];
  };
}
