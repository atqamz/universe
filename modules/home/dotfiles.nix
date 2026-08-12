{
  config,
  hostname,
  ...
}:
let
  link = config.lib.file.mkOutOfStoreSymlink;
  root = "${config.home.homeDirectory}/dotfiles";
in
{
  home.file = {
    ".config/foot/foot.ini".source = link "${root}/foot/foot.ini";
    ".config/hypr".source = link "${root}/hypr";
    ".config/zed".source = link "${root}/zed";
    ".config/herdr/config.toml" = {
      source = link "${root}/herdr/config.toml";
      force = true;
    };
    ".config/caelestia/shell.json" = {
      source = link "${root}/caelestia/hosts/${hostname}.json";
      force = true;
    };
    ".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/autoexec.cfg".source =
      link "${root}/cs2/autoexec.cfg";
    ".config/rtk/filters.toml".source = link "${root}/rtk/filters.toml";
    ".config/gtk-3.0/thunar.css".source = link "${root}/gtk/thunar-3.css";
    ".config/gtk-4.0/thunar.css".source = link "${root}/gtk/thunar-4.css";
    ".config/cava/config".source = link "${root}/cava/config";
  };

  universe.doctor.symlinks = {
    ".config/foot/foot.ini" = "dotfiles/foot/foot.ini";
  };
}
