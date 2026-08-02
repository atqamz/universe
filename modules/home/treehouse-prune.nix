{
  pkgs,
  inputs,
  config,
  ...
}:
let
  prune = pkgs.writeShellApplication {
    name = "treehouse-prune";
    runtimeInputs = [
      inputs.treehouse.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.git
    ];
    text = ''
      treehouse prune --all --yes
    '';
  };
in
{
  systemd.user.services.treehouse-prune = {
    Unit = {
      Description = "Prune stale treehouse worktree pools";
      OnFailure = [ "notify-failure@%n.service" ];
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = config.home.homeDirectory;
      ExecStart = "${prune}/bin/treehouse-prune";
    };
  };

  systemd.user.timers.treehouse-prune = {
    Unit.Description = "Weekly treehouse worktree pool prune";
    Timer = {
      OnCalendar = "weekly";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
