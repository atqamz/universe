_: {
  services.hyprpolkitagent.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    package = null;
  };
}
