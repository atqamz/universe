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
          openssh
        ])
        ++ (repo.extraTools or [ ]);
      text = ''
        dir="${repo.dir}"
        name="${repo.name}"
        if [ ! -d "$dir/.git" ]; then
          echo "$name not bootstrapped; run: nix run .#bootstrap"
          exit 0
        fi

        if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no)" ]; then
          echo "$name dirty; pull skipped"
          exit 0
        fi

        if ! git -C "$dir" pull --ff-only; then
          echo "$name pull failed" >&2
          exit 1
        fi
        ${repo.post or ""}
      '';
    };

  githubSync = pkgs.writeShellApplication {
    name = "github-sync";
    runtimeInputs = with pkgs; [
      git
      findutils
      coreutils
      openssh
    ];
    text = ''
      root="$HOME/github"
      [ -d "$root" ] || exit 0
      failed=0

      while read -r gitdir; do
        repo=$(dirname "$gitdir")
        name=''${repo#"$root"/}

        if ! git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
          continue
        fi

        if [ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ]; then
          echo "skip $name: dirty"
          continue
        fi

        if ! git -C "$repo" pull --ff-only -q; then
          echo "failed $name: pull failed" >&2
          failed=1
          continue
        fi

        echo "ok $name"
      done < <(find "$root" -name .git -type d -prune)

      exit "$failed"
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

  services.userTimers = lib.listToAttrs (
    map (
      unit:
      lib.nameValuePair "${unit.name}-sync" {
        description = "Pull ${unit.description}";
        timerDescription = "Periodic ${unit.name} sync";
        command = unit.bin;
        timer = {
          OnStartupSec = "2min";
          OnUnitActiveSec = unit.interval;
          Persistent = true;
        };
      }
    ) units
  );
}
