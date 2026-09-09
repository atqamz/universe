{ config, lib, ... }:
let
  home = config.home.homeDirectory;
  link = config.lib.file.mkOutOfStoreSymlink;
  readOnlyLinks = {
    ".claude/CLAUDE.md" = "universe/configs/dotagents/CLAUDE.md";
    ".claude/AGENTS.md" = "universe/configs/dotagents/AGENTS.md";
    ".claude/fetch-usage.sh" = "universe/configs/dotagents/claude/fetch-usage.sh";
    ".claude/statusline-command.sh" = "universe/configs/dotagents/claude/statusline-command.sh";
    ".config/opencode/AGENTS.md" = "universe/configs/dotagents/AGENTS.md";
    ".codex/AGENTS.md" = "universe/configs/dotagents/AGENTS.md";
    ".agents/skills/gh-ops" = "universe/configs/dotagents/skills/gh-ops";
    ".claude/skills/gh-ops" = "universe/configs/dotagents/skills/gh-ops";
    ".codex/skills/gh-ops" = "universe/configs/dotagents/skills/gh-ops";
  };
  dynamicModelLinks = {
    ".config/opencode/dynamic-models" = "universe/configs/dotagents/opencode/dynamic-models";
  };
  writableLinks = {
    ".claude/settings.json" = "universe/configs/dotagents/claude/settings.json";
    ".config/opencode/opencode.json" = "universe/configs/dotagents/opencode/opencode.json";
  };
in
{
  home.file =
    lib.mapAttrs (_path: target: { source = link "${home}/${target}"; }) readOnlyLinks
    // lib.mapAttrs (_path: target: { source = link "${home}/${target}"; }) dynamicModelLinks;

  systemd.user.tmpfiles.rules = [
    "d %h/.claude 0700 - - - -"
    "d %h/.config/opencode 0700 - - - -"
    "d %h/.config/opencode/plugins 0700 - - - -"
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

  universe.doctor = {
    paths = [ "universe/configs/dotagents" ];

    symlinks = writableLinks // dynamicModelLinks // readOnlyLinks;
  };
}
