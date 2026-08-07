{ pkgs, lib, ... }:
{
  home.packages = lib.mkAfter (
    with pkgs;
    [
      sourcegit
      (writeShellScriptBin "sourcegit" ''exec ${sourcegit}/bin/SourceGit "$@"'')
      unzip
      p7zip
      unar
      bun
      jq
      age
      sops
      gh
      firebase-tools
      google-cloud-sdk
      gws
      git-lfs
      hyprpicker
      grim
      slurp
      wl-clipboard
      cliphist
      fuzzel
      brightnessctl
      pavucontrol
      obs-studio
      vlc
      filezilla
      btop
      nvitop
      bitwarden-cli
      libreoffice
      tmux
      neovim
      handy
      starship
      zoxide
      eza
      lazygit
      podman-tui
    ]
  );
}
