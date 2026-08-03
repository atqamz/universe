{ pkgs, ... }:
let
  manifest = "$HOME/dotagents/skills/manifest.txt";
  sync = pkgs.writeShellApplication {
    name = "skills-sync";
    runtimeInputs = with pkgs; [
      bun
      coreutils
    ];
    text = ''
      manifest="${manifest}"

      if [ ! -f "$manifest" ]; then
        echo "skills-sync: missing manifest: $manifest" >&2
        exit 1
      fi

      while IFS= read -r source || [ -n "$source" ]; do
        case "$source" in
          ""|\#*) continue ;;
        esac

        echo "skills-sync: installing $source"
        bunx --yes skills add "$source" -g -a opencode -a claude-code --skill '*' -y
      done < "$manifest"
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
}
