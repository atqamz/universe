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
    ./dotai.nix
    ./dotfiles.nix
    ./git.nix
    ./claude-plugins.nix
    ./rtk.nix
    ./mise.nix
    ./qt.nix
    ./codedb.nix
    ./brain-sync.nix
    ./brain-promote.nix
    ./dotfiles-sync.nix
    ./dotai-sync.nix
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
