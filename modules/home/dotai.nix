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
  # Live symlinks into ~/.claude: editing the dotai checkout is instantly live,
  # no rebuild. Volatile ~/.claude state (projects/, auth, history) is untouched.
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

  # Expose brain helpers by bare name through the profile bin (always on PATH),
  # execing the live symlinks so dotai edits stay instantly live.
  home.packages = [
    (pkgs.writeShellScriptBin "brain-recall" ''
      exec "${config.home.homeDirectory}/.claude/bin/brain-recall" "$@"
    '')
    (pkgs.writeShellScriptBin "brain-promote" ''
      exec "${config.home.homeDirectory}/.claude/bin/brain-promote" "$@"
    '')
  ];
}
