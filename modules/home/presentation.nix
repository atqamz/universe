{ pkgs, ... }:
let
  clipboardPicker = pkgs.writeShellApplication {
    name = "clipboard-picker";
    runtimeInputs = with pkgs; [
      cliphist
      fuzzel
      wl-clipboard
    ];
    text = ''
      history="$(cliphist list)"
      choice="$(printf '%s\n' "$history" | fuzzel --dmenu)" || exit 0
      [ -n "$choice" ] || exit 0
      printf '%s\n' "$choice" | cliphist decode | wl-copy
    '';
  };

  clipboardWipe = pkgs.writeShellApplication {
    name = "clipboard-wipe";
    runtimeInputs = with pkgs; [
      cliphist
      libnotify
    ];
    text = ''
      cliphist wipe
      if ! notify-send Clipboard "History cleared"; then
        printf '%s\n' "clipboard-wipe: notification failed" >&2
      fi
    '';
  };

  screenshotClipboard = pkgs.writeShellApplication {
    name = "screenshot-clipboard";
    runtimeInputs = with pkgs; [
      grim
      wl-clipboard
    ];
    text = ''
      grim - | wl-copy
    '';
  };

  screenshotRegion = pkgs.writeShellApplication {
    name = "screenshot-region";
    runtimeInputs = with pkgs; [
      grim
      slurp
      wl-clipboard
    ];
    text = ''
      geometry="$(slurp)" || exit 0
      grim -g "$geometry" - | wl-copy
    '';
  };

  emojiPicker = pkgs.writeShellApplication {
    name = "emoji-picker";
    runtimeInputs = with pkgs; [
      fuzzel
      gnused
      wl-clipboard
    ];
    text = ''
      choices="$(sed -nE 's/^[^#]+# ([^ ]+) E[0-9.]+ (.+)$/\1 \2/p' ${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt)"
      choice="$(printf '%s\n' "$choices" | fuzzel --dmenu --prompt 'Emoji > ')" || exit 0
      [ -n "$choice" ] || exit 0
      printf '%s' "''${choice%% *}" | wl-copy
    '';
  };

  brightnessUp = pkgs.writeShellApplication {
    name = "brightness-up";
    runtimeInputs = [ pkgs.brightnessctl ];
    text = ''
      brightnessctl -q set 5%+
    '';
  };

  brightnessDown = pkgs.writeShellApplication {
    name = "brightness-down";
    runtimeInputs = [ pkgs.brightnessctl ];
    text = ''
      brightnessctl -q set 5%-
    '';
  };

  mediaNext = pkgs.writeShellApplication {
    name = "media-next";
    runtimeInputs = [ pkgs.playerctl ];
    text = ''
      playerctl next
    '';
  };

  mediaPrevious = pkgs.writeShellApplication {
    name = "media-previous";
    runtimeInputs = [ pkgs.playerctl ];
    text = ''
      playerctl previous
    '';
  };

  mediaPlayPause = pkgs.writeShellApplication {
    name = "media-play-pause";
    runtimeInputs = [ pkgs.playerctl ];
    text = ''
      playerctl play-pause
    '';
  };
in
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "sans-serif:size=13";
        lines = 8;
        width = 35;
        "horizontal-pad" = 20;
        "vertical-pad" = 16;
        "inner-pad" = 8;
      };
      border = {
        width = 2;
        radius = 18;
      };
      colors = {
        background = "201f23ff";
        text = "e5e1e7ff";
        prompt = "c8c5d1ff";
        input = "e5e1e7ff";
        placeholder = "918f9aff";
        match = "c2c1ffff";
        selection = "7171acff";
        "selection-text" = "ffffffff";
        "selection-match" = "c2c1ffff";
        counter = "918f9aff";
        border = "c2c1ffff";
      };
    };
  };

  home.packages = [
    clipboardPicker
    clipboardWipe
    screenshotClipboard
    screenshotRegion
    emojiPicker
    brightnessUp
    brightnessDown
    mediaNext
    mediaPrevious
    mediaPlayPause
  ];

  universe.doctor.commands = [
    "clipboard-picker"
    "clipboard-wipe"
    "screenshot-clipboard"
    "screenshot-region"
    "emoji-picker"
    "brightness-up"
    "brightness-down"
    "media-next"
    "media-previous"
    "media-play-pause"
  ];
}
