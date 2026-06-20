{
  inputs,
  pkgs,
  config,
  ...
}:
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  home.packages = [
    (pkgs.writeShellScriptBin "zen" ''exec ${config.programs.zen-browser.finalPackage}/bin/zen-beta "$@"'')
  ];

  programs.zen-browser = {
    enable = true;
    policies.DontCheckDefaultBrowser = true;
  };

  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http" = "zen-beta.desktop";
    "x-scheme-handler/https" = "zen-beta.desktop";
    "text/html" = "zen-beta.desktop";
    "x-scheme-handler/about" = "zen-beta.desktop";
    "x-scheme-handler/unknown" = "zen-beta.desktop";
  };
}
