_: {
  imports = [
    ./dotagents.nix
    ./nix-access-token.nix
    ./repo-pull-sync.nix
  ];

  home = {
    username = "atqa";
    homeDirectory = "/home/atqa";
    stateVersion = "26.05";
  };

  programs = {
    home-manager.enable = true;
    bash.enable = true;
  };
}
