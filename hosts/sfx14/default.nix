_: {
  imports = [
    ./hardware.nix
    ../disko.nix
  ];

  networking.hostName = "sfx14";

  universe = {
    capabilities = {
      ambientLight = true;
      knowledgeCorpus = true;
    };
    roles.zenProfileWriter = true;
  };

  boot.loader.systemd-boot.configurationLimit = 3;
}
