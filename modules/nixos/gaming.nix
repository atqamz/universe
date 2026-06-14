{ pkgs, ... }:
{
  # Steam needs 32-bit graphics (hardware.graphics.enable32Bit, set in gpu.nix)
  # and unfree (allowed in nix.nix). gamescopeSession gives a Big Picture-style
  # session launchable from the display manager.
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
    };

    # Micro-compositor for upscaling/HDR/frame limiting; gamescopeSession needs it.
    gamescope.enable = true;

    # Switches CPU governor to performance and raises priority while gaming.
    gamemode.enable = true;
  };

  environment.systemPackages = with pkgs; [
    mangohud # FPS/frametime/temp overlay
    protonup-qt # manage GE-Proton builds
  ];
}
