{ pkgs, ... }:
let
  notify = pkgs.writeShellApplication {
    name = "notify-failure";
    runtimeInputs = with pkgs; [
      libnotify
      systemd
      coreutils
    ];
    text = ''
      unit="$1"
      body="$(systemctl --user status --no-pager --lines=5 "$unit" 2>&1 | tail -n 5)"
      notify-send -u critical "$unit failed" "$body"
    '';
  };
in
{
  systemd.user.services."notify-failure@" = {
    Unit.Description = "Report the failure of %i";
    Service = {
      Type = "oneshot";
      ExecStart = "${notify}/bin/notify-failure %i";
    };
  };
}
