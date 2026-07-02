{ pkgs, ... }:
let
  sync = pkgs.writeShellApplication {
    name = "ninerouter-models-sync";
    runtimeInputs = with pkgs; [
      curl
      jq
      git
      coreutils
    ];
    text = ''
      set -euo pipefail

      key_file=/run/secrets/ninerouter-api-key
      config="$HOME/dotagents/opencode/opencode.json"
      base_url="https://router.luckynee.com/v1"

      if [ ! -r "$key_file" ]; then
        echo "ninerouter-models-sync: secret not available" >&2
        exit 1
      fi

      key=$(cat "$key_file")
      ids=$(curl -sS -m 15 -H "Authorization: Bearer $key" "$base_url/models" | jq -r '.data[].id' | sort)

      models=$(echo "$ids" | jq -R -s 'split("\n") | map(select(. != "")) | map({key: ., value: {name: .} + (if endswith("-thinking") then {reasoning: true} else {} end)}) | from_entries')

      tmp=$(mktemp)
      jq --argjson models "$models" '.provider."9router".models = $models' "$config" > "$tmp"

      if diff -q "$config" "$tmp" >/dev/null 2>&1; then
        echo "ninerouter-models-sync: no changes"
        rm -f "$tmp"
        exit 0
      fi

      cp "$tmp" "$config"
      rm -f "$tmp"

      cd "$HOME/dotagents"
      git add opencode/opencode.json
      git commit -m "sync 9router models"
      git push origin master
      echo "ninerouter-models-sync: pushed"
    '';
  };
in
{
  home.packages = [ sync ];

  systemd.user.services.ninerouter-models-sync = {
    Unit.Description = "Sync 9router model list";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/ninerouter-models-sync";
    };
  };

  systemd.user.timers.ninerouter-models-sync = {
    Unit.Description = "Periodic 9router model list sync";
    Timer = {
      OnStartupSec = "5min";
      OnUnitActiveSec = "6h";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
