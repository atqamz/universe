{ config, ... }:
{
  services.alloy = {
    enable = true;
    environmentFile = config.sops.secrets.alloy-env.path;
  };

  environment.etc."alloy/config.alloy".source = ./config.alloy;

  universe.doctor.activeSystemServices = [ "alloy" ];
}
