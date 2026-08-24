{
  pkgs,
  config,
  ...
}:
let
  prune = pkgs.writeShellApplication {
    name = "treehouse-prune";
    runtimeInputs = [
      pkgs.treehouse
      pkgs.git
    ];
    text = ''
      treehouse prune --all --verbose
    '';
  };
in
{
  services.userTimers.treehouse-prune = {
    description = "Prune stale treehouse worktree pools";
    timerDescription = "Weekly treehouse worktree pool prune";
    command = "${prune}/bin/treehouse-prune";
    serviceExtra.WorkingDirectory = config.home.homeDirectory;
    timer = {
      OnCalendar = "weekly";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };
}
