{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
  system = pkgs.stdenv.hostPlatform.system;
  claude = inputs.claude-code.packages.${system}.default;
  link = config.lib.file.mkOutOfStoreSymlink;
  reconcile = pkgs.writeShellApplication {
    name = "no-mistakes-reconcile";
    runtimeInputs = [
      claude
      pkgs.coreutils
      pkgs.codex
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
      pkgs.jq
      pkgs.no-mistakes
      pkgs.opencode
      pkgs.sqlite
    ];
    text = builtins.readFile ./no-mistakes-reconcile.sh;
  };
in
{
  home = {
    file.".no-mistakes/config.yaml" = {
      source = link "${home}/dotagents/no-mistakes/config.yaml";
      force = true;
    };

    activation.noMistakesSkill = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${reconcile}/bin/no-mistakes-reconcile refresh ${lib.escapeShellArg pkgs.no-mistakes.skill}
    '';

    packages = [
      pkgs.no-mistakes
      reconcile
    ];
  };

  services.userTimers.no-mistakes-reconcile = {
    description = "Reconcile the Nix-owned no-mistakes daemon executable";
    timerDescription = "Retry no-mistakes daemon reconciliation";
    command = "${reconcile}/bin/no-mistakes-reconcile reconcile";
    onActivation = "try";
    timer = {
      OnStartupSec = "5min";
      OnUnitActiveSec = "30min";
      Persistent = false;
    };
    serviceExtra.TimeoutStartSec = "2min";
  };

  universe = {
    doctor = {
      commands = lib.mkAfter [
        "no-mistakes"
        "no-mistakes-reconcile"
      ];
      symlinks.".no-mistakes/config.yaml" = "dotagents/no-mistakes/config.yaml";
      noMistakes = {
        binary = "${pkgs.no-mistakes}/bin/no-mistakes";
        config = ".no-mistakes/config.yaml";
        reconcile = "${reconcile}/bin/no-mistakes-reconcile";
        agents = [
          "codex"
          "claude"
        ];
        harnesses = [
          "claude"
          "codex"
          "opencode"
        ];
        skillSource = pkgs.no-mistakes.skill;
        skills = [
          ".agents/skills/no-mistakes/SKILL.md"
          ".claude/skills/no-mistakes/SKILL.md"
        ];
      };
    };
  };
}
