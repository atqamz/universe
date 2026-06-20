{ pkgs, ... }:
let
  termcmd = "${pkgs.ghostty}/bin/ghostty -e";
  yazi = "${pkgs.yazi}/bin/yazi";

  saveHelper = pkgs.writeShellApplication {
    name = "termfilechooser-yazi-save";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.yazi
    ];
    text = ''
      start="$1"; suggested="$(basename "$2")"; out="$3"
      tmp="$(mktemp)"
      yazi "$start" --cwd-file="$tmp"
      dir="$(cat "$tmp")"; rm -f "$tmp"
      [ -d "$dir" ] || dir="$HOME"
      read -e -i "$suggested" -r -p "Save as: " fname || true
      printf '%s\n' "$dir/''${fname:-$suggested}" > "$out"
    '';
  };

  chooser = pkgs.writeShellApplication {
    name = "termfilechooser-yazi";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      multiple="$1"; directory="$2"; save="$3"; path="$4"; out="$5"
      : "$multiple"

      start="$path"
      [ -e "$start" ] || start="$(dirname "$path")"
      [ -d "$start" ] || start="$HOME"

      if [ "$save" = "1" ]; then
        ${termcmd} ${saveHelper}/bin/termfilechooser-yazi-save "$start" "$path" "$out"
      elif [ "$directory" = "1" ]; then
        ${termcmd} ${yazi} "$start" --cwd-file="$out"
      else
        ${termcmd} ${yazi} "$start" --chooser-file="$out"
      fi
    '';
  };
in
{
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;

    plugins = {
      inherit (pkgs.yaziPlugins)
        mount
        ouch
        rich-preview
        smart-enter
        ;
    };

    settings = {
      mgr = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
      };

      opener = {
        open = [
          {
            run = ''xdg-open "$@"'';
            desc = "Open (default app)";
            for = "unix";
          }
        ];
        edit = [
          {
            run = ''zeditor "$@"'';
            desc = "Edit (zed)";
            block = false;
            for = "unix";
          }
        ];
        extract = [
          {
            run = ''ouch decompress "$@"'';
            desc = "Extract here (ouch)";
            for = "unix";
          }
        ];
      };

      open.rules = [
        {
          mime = "text/*";
          use = [
            "edit"
            "open"
          ];
        }
        {
          mime = "application/{json,javascript,x-shellscript,xml,toml,yaml}";
          use = [
            "edit"
            "open"
          ];
        }
        {
          mime = "image/*";
          use = [ "open" ];
        }
        {
          mime = "{audio,video}/*";
          use = [ "open" ];
        }
        {
          mime = "application/{zip,gzip,x-tar,x-bzip2,x-7z-compressed,x-rar,x-xz,zstd}";
          use = [
            "extract"
            "open"
          ];
        }
        {
          url = "*.{zip,tar,gz,tgz,bz2,7z,rar,xz,zst}";
          use = [
            "extract"
            "open"
          ];
        }
        {
          mime = "*";
          use = [
            "open"
            "edit"
          ];
        }
      ];

      plugin = {
        prepend_previewers = [
          {
            mime = "application/{zip,gzip,x-tar,x-bzip2,x-7z-compressed,x-rar,x-xz,zstd}";
            run = "ouch";
          }
          {
            url = "*.md";
            run = "rich-preview";
          }
          {
            url = "*.csv";
            run = "rich-preview";
          }
        ];
      };
    };

    keymap.mgr.prepend_keymap = [
      {
        on = [ "d" ];
        run = "remove";
        desc = "Trash selection";
      }
      {
        on = [ "D" ];
        run = "remove --permanent";
        desc = "Delete permanently";
      }
      {
        on = [ "<C-d>" ];
        run = ''shell 'dragon-drop -a -x -- "$@"' --confirm'';
        desc = "Drag selection (dragon)";
      }
      {
        on = [ "<C-S-d>" ];
        run = ''shell 'dragon-drop --target --print-path -x | while IFS= read -r f; do cp -rn -- "$f" ./; done' --block'';
        desc = "Receive dropped files (dragon)";
      }
      {
        on = [ "M" ];
        run = "plugin mount";
        desc = "Mount manager";
      }
      {
        on = [ "<Enter>" ];
        run = "plugin smart-enter";
        desc = "Enter dir / open file";
      }
      {
        on = [ "<C-a>" ];
        run = ''shell 'printf "Archive name: " && read -r n && [ -n "$n" ] && ouch compress "$@" "$n"' --block'';
        desc = "Create archive (ouch)";
      }
      {
        on = [ "<C-g>" ];
        run = ''shell 'printf "Mount URL (smb://host/share): " && read -r u && gio mount "$u"; printf "\n[enter to continue] " && read -r _ && ya emit cd "/run/user/$(id -u)/gvfs"' --block'';
        desc = "Connect to network share (gio)";
      }
    ];
  };

  xdg = {
    configFile."xdg-desktop-portal-termfilechooser/config".text = ''
      [filechooser]
      cmd=${chooser}/bin/termfilechooser-yazi
      default_dir=$HOME
    '';

    desktopEntries.yazi = {
      name = "yazi";
      comment = "Terminal file manager";
      exec = "${pkgs.ghostty}/bin/ghostty -e ${pkgs.yazi}/bin/yazi %f";
      icon = "system-file-manager";
      terminal = false;
      mimeType = [ "inode/directory" ];
      categories = [
        "System"
        "FileTools"
        "FileManager"
        "Utility"
      ];
    };

    mimeApps = {
      enable = true;
      defaultApplications."inode/directory" = "yazi.desktop";
    };
  };

  home.sessionVariables.GTK_USE_PORTAL = "1";

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never";
  };

  home.packages = with pkgs; [
    trash-cli
    ouch
    dragon-drop
    ffmpegthumbnailer
    poppler-utils
    imagemagick
    p7zip
    unar
    fd
    ripgrep
    file
    glib
    gvfs
  ];
}
