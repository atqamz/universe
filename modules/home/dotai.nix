{
  config,
  pkgs,
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
    ".claude/hooks/brain-capture.sh".source = link "${claude}/hooks/brain-capture.sh";
    ".claude/bin/brain-recall".source = link "${claude}/bin/brain-recall";
    ".claude/bin/brain-promote".source = link "${claude}/bin/brain-promote";

    ".codex/AGENTS.md".source = link "${root}/AGENTS.md";
  };

  home.packages = [
    (pkgs.writeShellScriptBin "brain-recall" ''
      exec "${config.home.homeDirectory}/.claude/bin/brain-recall" "$@"
    '')
  ];
}
