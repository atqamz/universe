{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  home.username = "atqa";
  home.homeDirectory = "/home/atqa";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # caelestia shell (bar/widgets/launcher) + cli. systemd-managed so uwsm's
  # graphical-session.target starts it; no exec-once needed in hyprland.
  # No `settings` here on purpose: the module writes shell.json as an immutable
  # store symlink, but caelestia self-mutates that file at runtime (theme/wallpaper
  # pickers) -> "Read-only file system". Instead the activation script below seeds
  # a WRITABLE shell.json and re-asserts our declarative keys via a jq merge, so
  # UI changes persist between switches while idle stays disabled.
  programs.caelestia = {
    enable = true;
    cli.enable = true;
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };
  };

  # Writable shell.json: drop any store symlink, merge our declarative keys
  # (idle disabled, wallpaper dir) into whatever caelestia last wrote.
  home.activation.caelestiaShellJson = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfgDir="$HOME/.config/caelestia"
    f="$cfgDir/shell.json"
    run mkdir -p "$cfgDir"
    if [ -L "$f" ]; then run rm -f "$f"; fi
    base="{}"
    if [ -f "$f" ]; then base="$(cat "$f")"; fi
    printf '%s' "$base" | ${pkgs.jq}/bin/jq \
      '.general.idle.lockBeforeSleep=false
       | .general.idle.timeouts=[]
       | .paths.wallpaperDir="~/Pictures/Wallpapers"' \
      > "$f.tmp" && run mv "$f.tmp" "$f"
  '';

  home.packages = with pkgs; [
    alacritty
    nautilus
    zed-editor
    inputs.zen-browser.packages.${pkgs.system}.default
    bibata-cursors
    # caelestia helpers
    jq
    hyprpicker
    grim
    slurp
    wl-clipboard
    brightnessctl
    playerctl
    pavucontrol
  ];

  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
  };

  # Own hyprland config (shell only from caelestia; wm config hand-written).
  # configType = "hyprlang" (.conf): at stateVersion 26.05 HM defaults to the
  # LUA backend, whose `hl.bind("a, b, c")` wants split args and has no `bindel`
  # — comma-strings and `bindel` only parse under hyprlang. Values come from nix
  # `let` bindings interpolated into the strings (no hyprland `$variables`).
  wayland.windowManager.hyprland =
    let
      terminal = "alacritty";
      browser = "zen-browser";
      editor = "zeditor";
      fileExplorer = "nautilus";
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
          # caelestia shell globals (registered by the quickshell)
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
