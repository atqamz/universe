{ pkgs, ... }:
{
  home.packages = [
    pkgs.firefox
    (pkgs.brave.override {
      commandLineArgs = "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations,PulseaudioLoopbackForScreenShare";
    })
  ];
}
