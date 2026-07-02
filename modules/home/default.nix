_: {
  imports = [
    ./packages.nix
    ./caelestia.nix
    ./clipboard.nix
    ./hypr.nix
    ./cursor.nix
    ./wezterm.nix
    ./file-management.nix
    ./vault-sync.nix
    ./password-store-sync.nix
    ./gpg-preset.nix
    ./secret-service.nix
    ./direnv.nix
    ./gtk.nix
    ./zen.nix
    ./zen-profile.nix
    ./dotagents.nix
    ./dotfiles.nix
    ./git.nix
    ./rtk.nix
    ./mise.nix
    ./qt.nix
    ./codedb.nix
    ./dotfiles-sync.nix
    ./dotagents-sync.nix
    ./skills-sync.nix
    ./ninerouter-models-sync.nix
    ./github-pull-sync.nix
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
