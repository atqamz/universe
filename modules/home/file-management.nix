{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    package = pkgs.yazi-unwrapped;

    settings.mgr = {
      show_hidden = false;
      sort_by = "natural";
      sort_dir_first = true;
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications."inode/directory" = "thunar.desktop";
  };

  home.sessionVariables.GTK_USE_PORTAL = "1";
}
