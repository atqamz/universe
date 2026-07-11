{ pkgs, lib, ... }:
let
  repos = [
    {
      name = "dotagents";
      dir = "$HOME/dotagents";
      description = "dotagents";
      interval = "5min";
    }
    {
      name = "dotfiles";
      dir = "$HOME/dotfiles";
      description = "dotfiles";
      interval = "5min";
    }
    {
      name = "vault";
      dir = "$HOME/vault";
      description = "secrets vault and import";
      interval = "1d";
      extraTools = with pkgs; [
        gnupg
        sops
        age
      ];
      post = ''( cd "$dir" && ./scripts/import.sh )'';
    }
    {
      name = "password-store";
      dir = "$HOME/.password-store";
      description = "password-store";
      interval = "1d";
    }
  ];

  mkSync =
    repo:
    pkgs.writeShellApplication {
      name = "${repo.name}-sync";
      runtimeInputs =
        (with pkgs; [
          git
          coreutils
          libnotify
        ])
        ++ (repo.extraTools or [ ]);
      text = ''
        dir="${repo.dir}"
        name="${repo.name}"
        if [ ! -d "$dir/.git" ]; then
          echo "$name not bootstrapped; run: nix run .#bootstrap" >&2
          exit 0
        fi

        if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no)" ]; then
          notify-send "$name-sync" "local $name changes uncommitted - skipping pull" || true
          echo "$name dirty, skipping pull" >&2
          exit 0
        fi

        git -C "$dir" pull --ff-only || \
          notify-send "$name-sync" "$name pull not fast-forward - diverged, skipping" || true
        ${repo.post or ""}
      '';
    };
in
{
  systemd.user.services = lib.listToAttrs (
    map (repo: {
      name = "${repo.name}-sync";
      value = {
        Unit.Description = "Pull ${repo.description}";
        Service = {
          Type = "oneshot";
          ExecStart = "${mkSync repo}/bin/${repo.name}-sync";
        };
      };
    }) repos
  );

  systemd.user.timers = lib.listToAttrs (
    map (repo: {
      name = "${repo.name}-sync";
      value = {
        Unit.Description = "Periodic ${repo.name} sync";
        Timer = {
          OnStartupSec = "2min";
          OnUnitActiveSec = repo.interval;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    }) repos
  );
}
