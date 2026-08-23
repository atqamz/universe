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
      libnotify
      bun
      jq
      age
      sops
      gh
      firebase-tools
      google-cloud-sdk
      git-lfs
      hyprpicker
      grim
      slurp
      wl-clipboard
      cliphist
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
