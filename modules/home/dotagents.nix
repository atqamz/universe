{ config, lib, ... }:
let
  root = "${config.home.homeDirectory}/dotagents";
  claude = "${root}/claude";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.file = {
    ".claude/CLAUDE.md".source = link "${root}/CLAUDE.md";
    ".claude/AGENTS.md".source = link "${root}/AGENTS.md";
    ".claude/fetch-usage.sh".source = link "${claude}/fetch-usage.sh";
    ".claude/statusline-command.sh".source = link "${claude}/statusline-command.sh";

    ".config/opencode/AGENTS.md".source = link "${root}/AGENTS.md";
    ".config/opencode/opencode.json" = {
      source = link "${root}/opencode/opencode.json";
      force = true;
    };
  };

  home.activation.claudeSettingsLink = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ln -sfn "${claude}/settings.json" "${config.home.homeDirectory}/.claude/settings.json"
  '';
}
