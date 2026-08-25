{
  config,
  lib,
  pkgs,
  ...
}:
let
  skillsCliVersion = "1.5.22";

  ledgerRelative = "${lib.removePrefix "${config.home.homeDirectory}/" config.xdg.stateHome}/universe/managed-skills";

  roots = [
    ".agents/skills"
    ".claude/skills"
    ".codex/skills"
  ];

  sources = {
    "DietrichGebert/ponytail" = [ "ponytail" ];
    "JuliusBrussee/caveman" = [ "caveman" ];
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
      ledger="''${HOME:?}/${ledgerRelative}"

      declare -A wanted=()
      for skill in ${lib.escapeShellArgs expected}; do
        wanted["$skill"]=1
      done

      retired=()
      if [ -f "$ledger" ]; then
        while IFS= read -r skill; do
          [ -n "$skill" ] || continue
          if [ -z "''${wanted[$skill]:-}" ]; then
            retired+=("$skill")
          fi
        done <"$ledger"
      fi

      for skill in "''${retired[@]}"; do
        echo "skills-sync: retiring $skill"
        for root in ${lib.escapeShellArgs roots}; do
          rm -rf -- "''${HOME:?}/$root/$skill"
        done
      done

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

      mkdir -p "$(dirname "$ledger")"
      staging="$(mktemp "$ledger.XXXXXX")"
      trap 'rm -f "$staging"' EXIT
      printf '%s\n' ${lib.escapeShellArgs expected} | sort >"$staging"
      mv "$staging" "$ledger"
      trap - EXIT
    '';
  };
in
{
  home.packages = [ sync ];

  universe.doctor = {
    expectedSkills = expected;
    skillLedger = ledgerRelative;
  };
}
