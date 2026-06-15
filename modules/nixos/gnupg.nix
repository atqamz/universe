{ pkgs, ... }:
let
  # gpg-agent wants a single pinentry binary, but we want the Qt dialog on the
  # desktop (matches the caelestia/Qt session) and a curses fallback when no
  # display is reachable (tty, SSH). Dispatch at invocation time on the agent's
  # display env. Exposed as bin/pinentry so pinentryPackage picks it up.
  pinentry-auto = pkgs.writeShellScriptBin "pinentry" ''
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
    pinentryPackage = pinentry-auto;
  };
}
