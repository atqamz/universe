{
  config,
  pkgs,
  hostname,
  ...
}:
let
  link = config.lib.file.mkOutOfStoreSymlink;
  root = "${config.home.homeDirectory}/dotfiles";
in
{
  home.packages = with pkgs; [
    starship
    direnv
    zoxide
    eza
    lazygit
    podman-tui
  ];

  home.file = {
    ".config/hypr".source = link "${root}/hypr";
    ".config/fish".source = link "${root}/fish";
    ".config/zed".source = link "${root}/zed";
    ".config/Code/User".source = link "${root}/vscode/User";
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
}
