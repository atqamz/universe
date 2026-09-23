{ pkgs, ... }:
{
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
    settings = {
      "allow-preset-passphrase" = "";
      default-cache-ttl = 86400;
      default-cache-ttl-ssh = 86400;
      max-cache-ttl = 34560000;
      max-cache-ttl-ssh = 34560000;
    };
  };
}
