_: {
  perSystem =
    { pkgs, ... }:
    let
      vault = "$HOME/secrets";
      rt = with pkgs; [
        git
        gh
        gnupg
        sops
        age
        coreutils
      ];

      export = pkgs.writeShellApplication {
        name = "secrets-export";
        runtimeInputs = rt;
        text = ''
          vault="${vault}"
          cd "$vault" || exit 1
          ./scripts/export.sh
          git add -A
          if git diff --cached --quiet; then
            echo "nothing to export"
            exit 0
          fi
          git commit -m "export live secrets"
          git push
        '';
      };

      bootstrap = pkgs.writeShellApplication {
        name = "secrets-bootstrap";
        runtimeInputs = rt;
        text = ''
          vault="${vault}"
          if [ ! -d "$vault/.git" ]; then
            echo "==> cloning vault"
            mkdir -p "$(dirname "$vault")"
            gh repo clone atqamz/secrets "$vault"
          else
            echo "==> updating vault"
            git -C "$vault" pull --ff-only
          fi
          cd "$vault" || exit 1
          ./scripts/import.sh
        '';
      };

      brainBootstrap = pkgs.writeShellApplication {
        name = "brain-bootstrap";
        runtimeInputs = rt;
        text = ''
          for repo in dotai brain; do
            dest="$HOME/$repo"
            if [ ! -d "$dest/.git" ]; then
              echo "==> cloning $repo"
              gh repo clone "atqamz/$repo" "$dest"
            else
              echo "==> updating $repo"
              git -C "$dest" pull --ff-only
            fi
          done
          if command -v qmd >/dev/null 2>&1; then
            echo "==> building brain index (qmd)"
            qmd collection add "$HOME/brain" --name brain 2>/dev/null || true
            qmd embed
          else
            echo "==> qmd not installed; skipping index build (grep recall still works)"
          fi
        '';
      };
    in
    {
      apps = {
        secrets-export = {
          type = "app";
          program = "${export}/bin/secrets-export";
        };
        secrets-bootstrap = {
          type = "app";
          program = "${bootstrap}/bin/secrets-bootstrap";
        };
        brain-bootstrap = {
          type = "app";
          program = "${brainBootstrap}/bin/brain-bootstrap";
        };
      };
    };
}
