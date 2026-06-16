{ pkgs, ... }:
let
  # Terminal command the portal file-chooser and the .desktop entry both spawn.
  # ghostty -e <cmd>: run a one-shot command in a fresh ghostty window.
  termcmd = "${pkgs.ghostty}/bin/ghostty -e";
  yazi = "${pkgs.yazi}/bin/yazi";

  # xdg-desktop-portal-termfilechooser calls this with a fixed positional
  # contract:
  #   $1 multiple  (1 = caller wants several files)
  #   $2 directory (1 = caller wants a directory, not a file)
  #   $3 save      (1 = save dialog, else open dialog)
  #   $4 path      (suggested file for save, or starting dir)
  #   $5 out       (file we must fill with the chosen paths, one per line)
  #
  # yazi is a browser, not a dialog box, so each mode maps to the closest yazi
  # behaviour:
  #   open      -> --chooser-file: space-select, Enter writes the selection
  #   directory -> --cwd-file: navigate in, q writes the current directory
  #   save      -> pick the target dir in yazi, then a readline prompt for the
  #               filename (prefilled with the app's suggestion, editable)
  # open + directory are exact; save is a two-step (browse then type) rather
  # than a single dialog, but you do get to name/rename the file.

  # Runs inside the spawned terminal for the save path: yazi to choose the
  # directory, then an editable filename prompt. Separate script so the
  # interactive prompt can follow yazi in one terminal window.
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
      : "$multiple"  # contract arg; selection count is driven by the user in yazi

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
  # ---- yazi itself -------------------------------------------------------
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;

    plugins = {
      inherit (pkgs.yaziPlugins)
        mount # M: list/mount/unmount removable + network block devices
        ouch # archive preview + one-key extract
        rich-preview # markdown / csv / rst rendered preview
        smart-enter # Enter: cd into dirs, open files (one key for both)
        ;
    };

    settings = {
      mgr = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
      };

      # How to act on a file once an opener rule picks a verb.
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

      # Map mime/name -> ordered list of openers. First entry is the default;
      # `o` uses it, `O` (open --interactive) shows the whole list = the
      # Nautilus "Open With..." menu.
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

      # Previewers: built-ins cover image/video/pdf; the plugins add archives
      # and rich text. Image/video/pdf previews render inline only in a
      # kitty-graphics terminal -> ghostty (see ghostty.nix).
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
      # Trash, not rm. `d` -> freedesktop trash (recoverable via trash-cli /
      # any trash UI). `D` is the explicit, unrecoverable delete.
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
      # Drag selection out to any Wayland/XWayland drop target via dragon.
      {
        on = [ "<C-d>" ];
        run = ''shell 'dragon-drop -a -x -- "$@"' --confirm'';
        desc = "Drag selection (dragon)";
      }
      # Drag INTO yazi: dragon opens a target window; drop files from another
      # app onto it and they are copied into the current directory. A terminal
      # can't itself be a drop target, so this proxy window is the workaround.
      {
        on = [ "<C-S-d>" ];
        run = ''shell 'dragon-drop --target --print-path -x | while IFS= read -r f; do cp -rn -- "$f" ./; done' --block'';
        desc = "Receive dropped files (dragon)";
      }
      # Removable + network drive manager.
      {
        on = [ "M" ];
        run = "plugin mount";
        desc = "Mount manager";
      }
      # One Enter for both: cd into a dir, open a file.
      {
        on = [ "<Enter>" ];
        run = "plugin smart-enter";
        desc = "Enter dir / open file";
      }
      # Create an archive from the selection. ouch picks the format from the
      # name you type (foo.tar.gz, foo.zip, ...). --block hands yazi the
      # terminal so the prompt is interactive.
      {
        on = [ "<C-a>" ];
        run = ''shell 'printf "Archive name: " && read -r n && [ -n "$n" ] && ouch compress "$@" "$n"' --block'';
        desc = "Create archive (ouch)";
      }
      # Connect to a network share (smb/sftp): gio mounts it under the gvfs
      # runtime dir, then yazi jumps there so you can browse it.
      {
        on = [ "<C-g>" ];
        run = ''shell 'printf "Mount URL (smb://host/share): " && read -r u && gio mount "$u"; printf "\n[enter to continue] " && read -r _ && ya emit cd "/run/user/$(id -u)/gvfs"' --block'';
        desc = "Connect to network share (gio)";
      }
    ];
  };

  xdg = {
    # portal file-chooser backend config. The nixos side
    # (modules/nixos/portal.nix) registers the termfilechooser backend; this
    # points it at our yazi wrapper. config dir name is fixed.
    configFile."xdg-desktop-portal-termfilechooser/config".text = ''
      [filechooser]
      cmd=${chooser}/bin/termfilechooser-yazi
      default_dir=$HOME
    '';

    # make yazi the default file manager for directories.
    desktopEntries.yazi = {
      name = "yazi";
      comment = "Terminal file manager";
      exec = "${pkgs.ghostty}/bin/ghostty -e ${pkgs.yazi}/bin/yazi %f";
      icon = "system-file-manager";
      terminal = false; # ghostty is itself the terminal window
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

  # GTK3 apps consult the portal for file dialogs only when this is set (GTK4
  # uses the portal unconditionally). Flipping it is what routes GTK file
  # pickers to termfilechooser -> yazi.
  home.sessionVariables.GTK_USE_PORTAL = "1";

  # ---- removable drives: auto-mount on insert ----------------------------
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never"; # daemon still automounts; no tray icon needed
  };

  # ---- supporting CLIs ---------------------------------------------------
  home.packages = with pkgs; [
    trash-cli # `d` in yazi shells out to the freedesktop trash; this is the CLI to list/restore
    ouch # extract (open rules) + create archives (<C-a>); the yazi ouch plugin shells out to this
    dragon-drop # drag-and-drop source/target (<C-d>)
    ffmpegthumbnailer # video thumbnails in previews
    poppler-utils # pdftoppm: pdf previews
    imagemagick # misc image conversion for previews
    p7zip # 7z back-end for ouch/extract
    unar # rar + odd-format extraction
    fd # yazi's fast file finder
    ripgrep # yazi's content search
    file # mime detection for opener rules
    glib # `gio` client for network mounts (smb/sftp)
    gvfs # gio mount back-ends (smb://, sftp://, mtp://)
  ];
}
