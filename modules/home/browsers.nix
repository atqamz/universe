{ pkgs, ... }:
{
  home.packages = [
    (pkgs.brave.override {
      commandLineArgs = "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations,PulseaudioLoopbackForScreenShare";
    })
  ];
}
