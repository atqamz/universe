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
    in
    {
      apps.secrets-export = {
        type = "app";
        program = "${export}/bin/secrets-export";
      };
      apps.secrets-bootstrap = {
        type = "app";
        program = "${bootstrap}/bin/secrets-bootstrap";
      };
    };
}
