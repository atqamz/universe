{
  config,
  pkgs,
  ...
}:
let
  dotai = "${config.home.homeDirectory}/dotai/claude";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.file = {
    ".claude/CLAUDE.md".source = link "${dotai}/CLAUDE.md";
    ".claude/context".source = link "${dotai}/context";
    ".claude/settings.json".source = link "${dotai}/settings.json";
    ".claude/fetch-usage.sh".source = link "${dotai}/fetch-usage.sh";
    ".claude/statusline-command.sh".source = link "${dotai}/statusline-command.sh";
    ".claude/hooks/brain-capture.sh".source = link "${dotai}/hooks/brain-capture.sh";
    ".claude/bin/brain-recall".source = link "${dotai}/bin/brain-recall";
    ".claude/bin/brain-promote".source = link "${dotai}/bin/brain-promote";
  };

  home.packages = [
    (pkgs.writeShellScriptBin "brain-recall" ''
      exec "${config.home.homeDirectory}/.claude/bin/brain-recall" "$@"
    '')
  ];
}
