{ pkgs, ... }:
let
  pinentryAuto = pkgs.writeShellScriptBin "pinentry" ''
    if [ -n "''${WAYLAND_DISPLAY:-}" ] || [ -n "''${DISPLAY:-}" ]; then
      exec ${pkgs.pinentry-qt}/bin/pinentry-qt "$@"
    fi
    exec ${pkgs.pinentry-curses}/bin/pinentry-curses "$@"
  '';
in
{
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pinentryAuto;
    settings = {
      "allow-preset-passphrase" = "";
      default-cache-ttl = 86400;
      default-cache-ttl-ssh = 86400;
      max-cache-ttl = 34560000;
      max-cache-ttl-ssh = 34560000;
    };
  };
}
