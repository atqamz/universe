{ inputs, ... }:
{
  imports = [ inputs.omanixy.homeManagerModules.default ];

  programs.omanixy.enable = true;

  universe.doctor = {
    activeUserServices = [ "omanixy-shell" ];
    commands = [ "omanixy-shell" ];
  };
}
