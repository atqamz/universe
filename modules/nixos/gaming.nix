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
      # Hybrid laptop (AMD Renoir iGPU primary + NVIDIA GTX 1650): the iGPU
      # renders by default. Send Steam and the games it launches to the dGPU
      # via PRIME render-offload env, set in the Steam FHS profile so the
      # client, Proton and gamescope children all inherit it.
      package = pkgs.steam.override {
        extraEnv = {
          __NV_PRIME_RENDER_OFFLOAD = "1";
          __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          __VK_LAYER_NV_optimus = "NVIDIA_only";
        };
      };
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
