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
    ".ssh/config" = {
      source = link "${root}/ssh/config";
      force = true;
    };
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
  };
}
