{ pkgs, lib, ... }:
let
  repos = [
    {
      name = "universe";
      dir = "$HOME/universe";
      description = "universe flake";
      interval = "5min";
    }
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

  githubSync = pkgs.writeShellApplication {
    name = "github-sync";
    runtimeInputs = with pkgs; [
      git
      findutils
      coreutils
    ];
    text = ''
      root="$HOME/github"
      [ -d "$root" ] || exit 0

      find "$root" -name .git -type d -prune | while read -r gitdir; do
        repo=$(dirname "$gitdir")
        name=''${repo#"$root"/}

        if ! git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
          continue
        fi

        if [ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ]; then
          echo "skip $name: dirty"
          continue
        fi

        if ! git -C "$repo" pull --ff-only -q >/dev/null 2>&1; then
          echo "skip $name: pull not fast-forward"
          continue
        fi

        echo "ok $name"
      done
    '';
  };

  units =
    (map (repo: {
      inherit (repo) name description interval;
      bin = "${mkSync repo}/bin/${repo.name}-sync";
    }) repos)
    ++ [
      {
        name = "github";
        description = "every repo under ~/github";
        interval = "15min";
        bin = "${githubSync}/bin/github-sync";
      }
    ];
in
{
  home.packages = [ githubSync ];

  systemd.user.services = lib.listToAttrs (
    map (unit: {
      name = "${unit.name}-sync";
      value = {
        Unit = {
          Description = "Pull ${unit.description}";
          OnFailure = [ "notify-failure@%n.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = unit.bin;
        };
      };
    }) units
  );

  systemd.user.timers = lib.listToAttrs (
    map (unit: {
      name = "${unit.name}-sync";
      value = {
        Unit.Description = "Periodic ${unit.name} sync";
        Timer = {
          OnStartupSec = "2min";
          OnUnitActiveSec = unit.interval;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    }) units
  );
}
