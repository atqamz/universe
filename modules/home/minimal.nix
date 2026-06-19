_: {
  imports = [
    ./dotai.nix
    ./brain-promote.nix
    ./brain-sync.nix
    ./qmd.nix
    ./secrets-sync.nix
    ./flake-autoupdate.nix
  ];

  home = {
    username = "atqa";
    homeDirectory = "/home/atqa";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
