{
  config,
  lib,
  pkgs,
  ...
}:
let
  remote = "https://github.com/atqamz/universe";
  preflight = pkgs.writeShellApplication {
    name = "universe-auto-upgrade-preflight";
    runtimeInputs = [ pkgs.git ];
    text = ''
      remote="''${1:?usage: universe-auto-upgrade-preflight REMOTE}"
      git ls-remote --exit-code "$remote" refs/heads/main >/dev/null
    '';
  };
in
{
  system.autoUpgrade = {
    enable = true;
    flake = "git+${remote}#${config.networking.hostName}";
    dates = "00/12:00";
    randomizedDelaySec = "60";
    flags = [
      "--refresh"
      "-L"
    ];
    operation = "switch";
  };

  systemd.services.nixos-upgrade.serviceConfig.ExecStartPre =
    "${lib.getExe preflight} ${lib.escapeShellArg remote}";
}
