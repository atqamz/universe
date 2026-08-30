{ pkgs, ... }:
{
  programs.foot.enable = true;

  # The launcher runs gtk-launch inside a transient unit created by `uwsm app -t
  # service`, which carries the systemd user manager's PATH rather than the
  # omanixy-shell process's. Omanixy provisions xdg-terminal-exec only on the
  # latter, so GLib still refuses every Terminal=true entry without this: it must
  # be reachable from the user profile. Remove once atqamz/omanixy#50 lands a fix
  # that survives that boundary.
  home.packages = [ pkgs.xdg-terminal-exec ];
}
