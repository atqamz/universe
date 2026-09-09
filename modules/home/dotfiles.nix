{
  config,
  lib,
  ...
}:
let
  link = config.lib.file.mkOutOfStoreSymlink;
  root = "${config.home.homeDirectory}/universe/configs/dotfiles";
  links = {
    ".config/foot/foot.ini".target = "foot/foot.ini";
    ".config/hypr".target = "hypr";
    ".config/zed".target = "zed";
    ".config/herdr/config.toml" = {
      target = "herdr/config.toml";
      force = true;
    };
    ".config/omarchy/shell.toml" = {
      target = "omarchy/shell.toml";
      force = true;
    };
    ".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/autoexec.cfg".target =
      "cs2/autoexec.cfg";
    ".config/rtk/filters.toml".target = "rtk/filters.toml";
    ".config/gtk-3.0/thunar.css".target = "gtk/thunar.css";
    ".config/gtk-4.0/thunar.css".target = "gtk/thunar.css";
    ".config/cava/config".target = "cava/config";
  };
in
{
  home.file = lib.mapAttrs (
    _path: value:
    {
      source = link "${root}/${value.target}";
    }
    // lib.optionalAttrs (value.force or false) { force = true; }
  ) links;

  universe.doctor = {
    paths = [ "universe/configs/dotfiles" ];
    symlinks = lib.mapAttrs (_path: value: "universe/configs/dotfiles/${value.target}") links;
  };
}
