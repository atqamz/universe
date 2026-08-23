{ inputs, ... }:
{
  imports = [ inputs.omanixy.nixosModules.default ];

  programs.omanixy.security = {
    pam.password.enable = true;
    polkit.system.enable = true;
  };
}
