{ pkgs, ... }:
{
  home.file.".config/opencode/plugins/rtk.ts".source = "${pkgs.rtk.src}/hooks/opencode/rtk.ts";

  universe.doctor = {
    commands = [ "rtk" ];
    paths = [ ".config/opencode/plugins/rtk.ts" ];
    absentPaths = [ ".claude/RTK.md" ];
  };
}
