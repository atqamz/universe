{ config, lib, ... }:
let
  root = "${config.home.homeDirectory}/dotagents";
  claude = "${root}/claude";
  home = config.home.homeDirectory;
  link = config.lib.file.mkOutOfStoreSymlink;
  writableLinks = {
    ".claude/settings.json" = "dotagents/claude/settings.json";
    ".config/opencode/opencode.json" = "dotagents/opencode/opencode.json";
  };
in
{
  home.file = {
    ".claude/CLAUDE.md".source = link "${root}/CLAUDE.md";
    ".claude/AGENTS.md".source = link "${root}/AGENTS.md";
    ".claude/fetch-usage.sh".source = link "${claude}/fetch-usage.sh";
    ".claude/statusline-command.sh".source = link "${claude}/statusline-command.sh";

    ".config/opencode/AGENTS.md".source = link "${root}/AGENTS.md";

    ".codex/AGENTS.md".source = link "${root}/AGENTS.md";
  };

  systemd.user.tmpfiles.rules = [
    "d %h/.claude 0700 - - - -"
    "d %h/.config/opencode 0700 - - - -"
    "d %h/.codex 0700 - - - -"
  ]
  ++ lib.mapAttrsToList (path: target: "L+ %h/${path} - - - - %h/${target}") writableLinks;

  home.activation.writableAgentSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p "${home}/.claude" "${home}/.config/opencode"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        path: target: ''run ln -sfn "${home}/${target}" "${home}/${path}"''
      ) writableLinks
    )}
  '';

  universe.doctor.symlinks = writableLinks // {
    ".codex/AGENTS.md" = "dotagents/AGENTS.md";
  };
}
