{ pkgs, ... }:
{
  # ghostty replaces alacritty as the default terminal: it speaks the kitty
  # graphics protocol natively, which is what yazi needs for inline image, PDF
  # and video-thumbnail previews (alacritty supports no image protocol at all).
  home.packages = [ pkgs.ghostty ];

  # ghostty reads ~/.config/ghostty/config. Kitty graphics is on by default, so
  # nothing to enable for previews; this just sets the look to match the rest of
  # the session.
  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-size = 12
    theme = catppuccin-mocha
    background-opacity = 0.95
    window-padding-x = 8
    window-padding-y = 8
    cursor-style = block
    confirm-close-surface = false
    gtk-single-instance = true
  '';
}
