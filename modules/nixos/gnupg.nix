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
    # allow-preset-passphrase lets the login-time gpg-preset service unlock the
    # subkeys headlessly via gpg-preset-passphrase (modules/home/gpg-preset.nix),
    # so git-over-ssh and signing work after a reboot with no interactive
    # pinentry. Empty value renders the bare flag; gpg-agent rejects
    # `allow-preset-passphrase true`. Long TTLs keep the preset alive for the
    # machine's whole uptime.
    settings = {
      "allow-preset-passphrase" = "";
      default-cache-ttl = 86400;
      default-cache-ttl-ssh = 86400;
      max-cache-ttl = 34560000;
      max-cache-ttl-ssh = 34560000;
    };
  };
}
