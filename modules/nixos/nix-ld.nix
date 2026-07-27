{ pkgs, ... }:
{
  programs.nix-ld.libraries = with pkgs; [
    atk
    cairo
    fontconfig
    gdk-pixbuf
    glib
    gtk3
    harfbuzz
    icu
    libglvnd
    libx11
    libxcursor
    libxrandr
    pango
  ];
}
