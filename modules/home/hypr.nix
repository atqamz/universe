_: {
  services.hyprpolkitagent.enable = true;

  # configType "hyprlang": the HM 26.05 default lua backend has no `bindel`
  # and wants split bind args, so comma-strings would not parse.
  wayland.windowManager.hyprland =
    let
      terminal = "alacritty";
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

        # Hyprland has no default placement for floating windows, so apps that
        # request no position open at 0,0 (top-left). Center them on spawn.
        windowrule = [
          # Hyprland 0.53+ windowrule v3 grammar: comma-separated "key value"
          # fields. Matchers take a "match:" prefix; the floating matcher prop
          # is named "float" (not "floating"). "center 1" is the effect.
          "center 1, match:float 1"
        ];

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          touchpad.natural_scroll = true;
        };

        # Hyprland 0.51+ dropped gestures:workspace_swipe for the `gesture`
        # keyword: "<fingers>, <direction>, <action>" (legacy/hyprlang parser).
        # horizontal = swipe either way to move between workspaces.
        gesture = [
          "3, horizontal, workspace"
        ];

        bind = [
          "${mod}, Return, exec, ${terminal}"
          "${mod}, E, exec, ${fileExplorer}"
          "${mod}, C, exec, hyprpicker -a"

          "${mod}, Space, global, caelestia:launcher"
          "${mod}, L, global, caelestia:session"
          "${mod} SHIFT, L, global, caelestia:lock"
          "${mod}, V, exec, caelestia clipboard"
          "${mod}, period, exec, caelestia emoji --picker"
          "${mod} ALT, P, exec, passmenu"

          "${mod} SHIFT, Q, killactive,"
          "${mod}, Q, togglefloating,"
          "${mod}, F, fullscreen,"
          "${mod}, J, layoutmsg, togglesplit"
          "${mod}, P, pseudo,"
          "${mod} SHIFT, left, swapwindow, l"
          "${mod} SHIFT, right, swapwindow, r"
          "${mod} SHIFT, up, swapwindow, u"
          "${mod} SHIFT, down, swapwindow, d"
          "${mod} CTRL, up, resizeactive, 0 -50"
          "${mod} CTRL, down, resizeactive, 0 50"
          "${mod}, G, togglegroup,"
          "${mod} ALT, G, moveoutofgroup,"
          "${mod} ALT, left, moveintogroup, l"
          "${mod} ALT, right, moveintogroup, r"
          "${mod} ALT, up, moveintogroup, u"
          "${mod} ALT, down, moveintogroup, d"
          "${mod} CTRL, left, changegroupactive, b"
          "${mod} CTRL, right, changegroupactive, f"

          "${mod}, left, movefocus, l"
          "${mod}, right, movefocus, r"
          "${mod}, up, movefocus, u"
          "${mod}, down, movefocus, d"
          "CTRL ALT, Tab, focusmonitor, +1"
          "${mod}, mouse_down, workspace, e+1"
          "${mod}, mouse_up, workspace, e-1"
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

          ",XF86AudioNext, global, caelestia:mediaNext"
          ",XF86AudioPrev, global, caelestia:mediaPrev"
          ",XF86AudioPlay, global, caelestia:mediaToggle"
          ",Print, global, caelestia:screenshotClip"
          "${mod} SHIFT, S, global, caelestia:screenshot"
        ];

        bindm = [
          "${mod}, mouse:272, movewindow"
          "${mod}, mouse:273, resizewindow"
          "${mod} SHIFT, mouse:272, resizewindow"
        ];

        bindel = [
          ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86MonBrightnessUp, global, caelestia:brightnessUp"
          ",XF86MonBrightnessDown, global, caelestia:brightnessDown"
        ];
      };
    };
}
