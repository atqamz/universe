{ inputs, ... }:
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;
    # DontCheckDefaultBrowser stops Zen nagging "set as default" on every
    # launch. The OS-side default is asserted declaratively below (xdg.mimeApps)
    # rather than via setAsDefaultBrowser, so it doesn't fight the mimeApps list
    # managed in file-management.nix.
    policies.DontCheckDefaultBrowser = true;
  };

  # Make Zen the default for web URLs/HTML. Desktop id is zen-beta.desktop (the
  # beta variant). Merges with the inode/directory default in file-management.nix.
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http" = "zen-beta.desktop";
    "x-scheme-handler/https" = "zen-beta.desktop";
    "text/html" = "zen-beta.desktop";
    "x-scheme-handler/about" = "zen-beta.desktop";
    "x-scheme-handler/unknown" = "zen-beta.desktop";
  };
}
