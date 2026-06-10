_: {
  services.hyprpolkitagent.enable = true;

  # configType "hyprlang": the HM 26.05 default lua backend has no `bindel`
  # and wants split bind args, so comma-strings would not parse.
  wayland.windowManager.hyprland =
    let
      terminal = "alacritty";
      browser = "zen-browser";
      editor = "zeditor";
      fileExplorer = "alacritty -e yazi";
      mod = "SUPER";
    in
    {
      enable = true;
      systemd.enable = false; # uwsm owns the session
      configType = "hyprlang";
      settings = {
        monitor = [
          "eDP-1,preferred,auto,1"
          "HDMI-A-1,preferred,auto,auto"
        ];

        env = [
          "HYPRCURSOR_THEME,Bibata-Modern-Classic"
          "XCURSOR_THEME,Bibata-Modern-Classic"
          "XCURSOR_SIZE,24"
        ];

        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          layout = "dwindle";
        };

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          touchpad.natural_scroll = true;
        };

        bind = [
          "${mod}, Return, exec, ${terminal}"
          "${mod}, Q, killactive,"
          "${mod}, M, exit,"
          "${mod}, E, exec, ${fileExplorer}"
          "${mod}, B, exec, ${browser}"
          "${mod}, C, exec, ${editor}"
          "${mod}, V, togglefloating,"
          "${mod}, F, fullscreen,"
          "${mod}, left, movefocus, l"
          "${mod}, right, movefocus, r"
          "${mod}, up, movefocus, u"
          "${mod}, down, movefocus, d"
          "${mod}, 1, workspace, 1"
          "${mod}, 2, workspace, 2"
          "${mod}, 3, workspace, 3"
          "${mod}, 4, workspace, 4"
          "${mod}, 5, workspace, 5"
          "${mod} SHIFT, 1, movetoworkspace, 1"
          "${mod} SHIFT, 2, movetoworkspace, 2"
          "${mod} SHIFT, 3, movetoworkspace, 3"
          "${mod} SHIFT, 4, movetoworkspace, 4"
          "${mod} SHIFT, 5, movetoworkspace, 5"
          "${mod}, Space, global, caelestia:launcher"
          "${mod}, X, global, caelestia:session"
        ];

        bindm = [
          "${mod}, mouse:272, movewindow"
          "${mod}, mouse:273, resizewindow"
        ];

        bindel = [
          ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86MonBrightnessUp, exec, brightnessctl s 5%+"
          ",XF86MonBrightnessDown, exec, brightnessctl s 5%-"
        ];
      };
    };
}
