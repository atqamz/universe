{
  config,
  ...
}:
let
  root = "${config.home.homeDirectory}/dotai";
  claude = "${root}/claude";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.file = {
    ".claude/CLAUDE.md".source = link "${root}/CLAUDE.md";
    ".claude/AGENTS.md".source = link "${root}/AGENTS.md";
    ".claude/settings.json".source = link "${claude}/settings.json";
    ".claude/fetch-usage.sh".source = link "${claude}/fetch-usage.sh";
    ".claude/statusline-command.sh".source = link "${claude}/statusline-command.sh";
    ".claude/hooks/ground-rules.sh".source = link "${claude}/hooks/ground-rules.sh";
    ".claude/skills/lavish/SKILL.md".source = link "${claude}/skills/lavish/SKILL.md";

    ".config/opencode/AGENTS.md".source = link "${root}/AGENTS.md";
  };
}
