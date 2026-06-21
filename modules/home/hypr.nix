{ hostname, lib, ... }:
let
  isSfx14 = hostname == "sfx14";
in
{
  services.hyprpolkitagent.enable = true;

  wayland.windowManager.hyprland =
    let
      terminal = "ghostty";
      fileExplorer = "ghostty -e yazi";
      mod = "SUPER";
      monitors =
        if isSfx14 then
          [
            "eDP-1,2160x1350@120,0x0,1"
            "DP-1,2160x1350@60,-2160x0,1"
          ]
        else
          [ "eDP-1,1920x1080@60,auto,1" ];
      moveBinds = lib.optionals isSfx14 [
        "${mod} SHIFT, comma, exec, hyprctl keyword monitor DP-1,2160x1350@60,-2160x0,1"
        "${mod} SHIFT, period, exec, hyprctl keyword monitor DP-1,2160x1350@60,2160x0,1"
      ];
      touchDevices = lib.optionals isSfx14 [
        {
          name = "ilitek-ilitek-tp";
          output = "DP-1";
        }
        {
          name = "ilitek-ilitek-tp-mouse";
          output = "DP-1";
          enabled = true;
        }
        {
          name = "syna7db5:00-06cb:ceb1-touchpad";
          accel_profile = "custom 0.5 0.0 1.0 2.0 3.0";
        }
      ];
    in
    {
      enable = true;
      systemd.enable = false;
      configType = "hyprlang";
      settings = {
        monitor = monitors;

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

        animations = {
          enabled = true;
          animation = [
            "workspaces, 1, 6, default, slidevert"
          ];
        };

        windowrule = [
          "center 1, match:float 1, match:xwayland 0"
        ];

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          touchpad.natural_scroll = true;
        }
        // lib.optionalAttrs isSfx14 {
          touchdevice.output = "DP-1";
          tablet.output = "DP-1";
        };

        device = touchDevices;

        gesture = [
          "3, vertical, workspace"
        ];

        bind = [
          "${mod}, Return, exec, ${terminal}"
          "${mod}, E, exec, ${fileExplorer}"
          "${mod}, C, exec, hyprpicker -a"

          "${mod}, Space, global, caelestia:launcher"
          "${mod}, L, global, caelestia:session"
          "${mod} SHIFT, L, global, caelestia:lock"
          "${mod}, V, exec, caelestia clipboard"
          "${mod} ALT, V, exec, sh -c 'cliphist wipe && notify-send Clipboard \"History cleared\" || true'"
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
        ]
        ++ moveBinds;

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
