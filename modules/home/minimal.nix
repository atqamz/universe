_: {
  imports = [
    ./dotagents.nix
    ./vault-sync.nix
    ./password-store-sync.nix
  ];

  home = {
    username = "atqa";
    homeDirectory = "/home/atqa";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
