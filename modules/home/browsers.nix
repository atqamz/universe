{ pkgs, ... }:
{
  home.packages = [
    pkgs.firefox
    (pkgs.brave.override {
      commandLineArgs = "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations,PulseaudioLoopbackForScreenShare";
    })
  ];

  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "x-scheme-handler/about" = "firefox.desktop";
    "x-scheme-handler/unknown" = "firefox.desktop";
  };
}
