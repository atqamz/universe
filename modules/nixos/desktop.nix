{ pkgs, ... }:
let
  archiveManager = pkgs.file-roller.overrideAttrs (previous: {
    buildInputs = builtins.filter (package: package != pkgs.nautilus) previous.buildInputs;
    mesonFlags = (previous.mesonFlags or [ ]) ++ [
      "-Dnautilus-actions=disabled"
      "-Dpackagekit=false"
    ];
  });
in
{
  programs = {
    appimage = {
      enable = true;
      binfmt = true;
    };
    hyprland = {
      enable = true;
      withUWSM = true;
    };
    nix-ld.enable = true;
    thunar = {
      enable = true;
      plugins = with pkgs; [
        thunar-archive-plugin
        thunar-volman
      ];
    };
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

    tumbler.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;
  };
  security.polkit.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.systemPackages = [ archiveManager ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];
}
