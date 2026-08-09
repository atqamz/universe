{
  config,
  lib,
  pkgs,
  ...
}:
let
  ghCredentialHelper = "!${lib.getExe pkgs.gh} auth git-credential";
in
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Atqa Munzir";
        email = "atqamz@gmail.com";
      };
      credential."https://github.com".helper = ghCredentialHelper;
      credential."https://gist.github.com".helper = ghCredentialHelper;
      fetch.prune = true;
    };
    signing = {
      key = "8AD7D4A302EE6771";
      signByDefault = true;
    };
    lfs.enable = true;
    includes = [
      {
        condition = "gitdir:${config.home.homeDirectory}/github/yes2games/";
        contents.user.email = "atqa@yes2games.com";
      }
    ];
  };
}
