_: {
  imports = [
    ./packages.nix
    ./caelestia.nix
    ./clipboard.nix
    ./hypr.nix
    ./cursor.nix
    ./yazi.nix
    ./secrets-sync.nix
    ./dotai.nix
    ./brain-sync.nix
    ./flake-autoupdate.nix
    ./qmd.nix
    ./passmenu.nix
    ./fuzzel.nix
  ];

  home = {
    username = "atqa";
    homeDirectory = "/home/atqa";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
