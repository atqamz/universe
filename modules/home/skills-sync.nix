{ lib, pkgs, ... }:
let
  skillsCliVersion = "1.5.22";

  sources = {
    "atqamz/gw" = [ "google-workspace" ];
    "obra/superpowers" = [
      "brainstorming"
      "dispatching-parallel-agents"
      "executing-plans"
      "finishing-a-development-branch"
      "receiving-code-review"
      "requesting-code-review"
      "subagent-driven-development"
      "systematic-debugging"
      "test-driven-development"
      "using-git-worktrees"
      "using-superpowers"
      "verification-before-completion"
      "writing-plans"
      "writing-skills"
    ];
    "pbakaus/impeccable" = [ "impeccable" ];
  };

  expected = lib.concatLists (lib.attrValues sources);

  forbidden = [
    "caveman"
    "caveman-commit"
    "caveman-compress"
    "caveman-help"
    "caveman-review"
    "caveman-stats"
    "cavecrew"
    "ponytail"
    "ponytail-audit"
    "ponytail-debt"
    "ponytail-gain"
    "ponytail-help"
    "ponytail-review"
  ];

  install = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      source: skills:
      let
        flags = lib.concatMapStringsSep " " (skill: "--skill ${lib.escapeShellArg skill}") skills;
      in
      ''
        echo "skills-sync: installing ${source}"
        bunx --yes skills@${skillsCliVersion} add ${lib.escapeShellArg source} -g -a opencode -a claude-code -a codex ${flags} -y
      ''
    ) sources
  );

  sync = pkgs.writeShellApplication {
    name = "skills-sync";
    runtimeInputs = with pkgs; [
      bun
      coreutils
    ];
    text = ''
      ${install}

      mkdir -p "$HOME/.codex/skills"
      for skill in ${lib.escapeShellArgs expected}; do
        real="$HOME/.agents/skills/$skill"
        if [ ! -d "$real" ]; then
          echo "skills-sync: expected skill not installed: $real" >&2
          exit 1
        fi
        ln -sfn "$real" "$HOME/.codex/skills/$skill"
      done

      for skill in ${lib.escapeShellArgs forbidden}; do
        for root in "$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.codex/skills"; do
          if [ -e "$root/$skill" ] || [ -L "$root/$skill" ]; then
            echo "skills-sync: removed skill still present: $root/$skill" >&2
            exit 1
          fi
        done
      done
    '';
  };
in
{
  home.packages = [ sync ];

  services.userTimers.skills-sync = {
    description = "Sync global agent skills";
    timerDescription = "Periodic global agent skills sync";
    command = "${sync}/bin/skills-sync";
    timer = {
      OnStartupSec = "3min";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
  };

  universe.doctor = {
    expectedSkills = expected;
    forbiddenSkills = forbidden;
  };
}
