_: {
  imports = [
    ./packages.nix
    ./caelestia.nix
    ./clipboard.nix
    ./hypr.nix
    ./cursor.nix
    ./ghostty.nix
    ./file-management.nix
    ./secrets-sync.nix
    ./gpg-preset.nix
    ./gtk.nix
    ./zen.nix
    ./zen-profile.nix
    ./dotai.nix
    ./git.nix
    ./claude-plugins.nix
    ./brain-sync.nix
    ./brain-promote.nix
    ./qmd.nix
    ./passmenu.nix
    ./fuzzel.nix
    ./readline.nix
  ];

  home = {
    username = "atqa";
    homeDirectory = "/home/atqa";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
