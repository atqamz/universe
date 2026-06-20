{ pkgs, ... }:
{
  home.packages = [ pkgs.ghostty ];

  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-size = 12
    theme = Catppuccin Mocha
    background-opacity = 0.95
    window-padding-x = 8
    window-padding-y = 8
    cursor-style = block
    confirm-close-surface = false
    gtk-single-instance = true

    shell-integration-features = ssh-env,ssh-terminfo
  '';
}
