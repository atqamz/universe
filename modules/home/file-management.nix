{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    package = pkgs.yazi-unwrapped;

    settings = {
      mgr = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
      };

      opener.extract = [
        {
          run = ''unar "$1"'';
          desc = "Extract here";
          for = "unix";
        }
      ];

      open.prepend_rules = [
        {
          mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
          use = "extract";
        }
      ];
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications."inode/directory" = "thunar.desktop";
  };

  home.sessionVariables.GTK_USE_PORTAL = "1";

  # writableMimeApps turns the managed symlink into a real file, so each switch HM
  # would back it up to mimeapps.list.bak and collide with the previous backup;
  # force overwrites in place instead of backing up.
  xdg.configFile."mimeapps.list".force = true;

  home.activation.writableMimeApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    file="${config.home.homeDirectory}/.config/mimeapps.list"
    if [ -L "$file" ]; then
      target="$(${pkgs.coreutils}/bin/readlink -f "$file")"
      ${pkgs.coreutils}/bin/cp --remove-destination "$target" "$file"
      ${pkgs.coreutils}/bin/chmod u+w "$file"
    fi
  '';
}
