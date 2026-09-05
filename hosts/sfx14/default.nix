_: {
  imports = [
    ./hardware.nix
    ../disko.nix
  ];

  networking.hostName = "sfx14";

  universe = {
    capabilities = {
      ambientLight = true;
      handFleet = true;
      knowledgeCorpus = true;
    };
  };

  boot.loader = {
    systemd-boot.configurationLimit = 3;
    timeout = 1;
  };
}
