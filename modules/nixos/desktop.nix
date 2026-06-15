{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  services = {
    greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start -e -D Hyprland hyprland.desktop'";
        user = "greeter";
      };
    };

    printing.enable = true;

    # udisks2: lets udiskie (home) mount removable drives without root.
    # gvfs: gio back-ends so yazi can open smb:// / sftp:// network shares.
    udisks2.enable = true;
    gvfs.enable = true;
  };
  security.polkit.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];
}
