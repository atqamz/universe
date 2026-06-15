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
    theme = Catppuccin Mocha
    background-opacity = 0.95
    window-padding-x = 8
    window-padding-y = 8
    cursor-style = block
    confirm-close-surface = false
    gtk-single-instance = true

    # ghostty advertises TERM=xterm-ghostty, whose terminfo most remote hosts
    # lack -- so `ssh host` then `tmux` fails with "missing or unsuitable
    # terminal: xterm-ghostty". ssh-terminfo installs ghostty's terminfo on the
    # remote on first connect; ssh-env falls back to TERM=xterm-256color when
    # that can't happen (e.g. read-only remote).
    shell-integration-features = ssh-env,ssh-terminfo
  '';
}
