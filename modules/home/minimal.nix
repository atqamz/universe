_: {
  imports = [
    ./dotagents.nix
    ./nix-access-token.nix
    ./notify-failure.nix
    ./repo-sync.nix
    ./user-timers.nix
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
