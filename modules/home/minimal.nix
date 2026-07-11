_: {
  imports = [
    ./dotagents.nix
    ./repo-pull-sync.nix
  ];

  home = {
    username = "atqa";
    homeDirectory = "/home/atqa";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
