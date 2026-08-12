{ pkgs, lib, ... }:
let
  repos = [
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

  units = map (repo: {
    inherit (repo) name description interval;
    bin = "${mkSync repo}/bin/${repo.name}-sync";
  }) repos;
in
{
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
