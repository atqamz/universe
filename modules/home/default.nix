_: {
  imports = [
    ./packages.nix
    ./caelestia.nix
    ./hypr.nix
    ./cursor.nix
    ./yazi.nix
  ];

  home = {
    username = "atqa";
    homeDirectory = "/home/atqa";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
