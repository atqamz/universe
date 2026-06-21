{
  config,
  pkgs,
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
    ".config/fastfetch".source = link "${root}/fastfetch";
    ".config/zed".source = link "${root}/zed";
    ".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/autoexec.cfg".source =
      link "${root}/cs2/autoexec.cfg";
  };
}
