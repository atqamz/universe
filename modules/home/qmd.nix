{ pkgs, ... }:
let
  # FHS env so node-llama-cpp / better-sqlite3 find a normal libc/libstdc++.
  # Spike (docs/superpowers/notes/qmd-nixos-spike.md) confirmed this builds and runs.
  qmdFhs = pkgs.buildFHSEnv {
    name = "qmd";
    targetPkgs =
      p: with p; [
        nodejs_22
        python3
        gcc
        gnumake
        stdenv.cc.cc.lib
        zlib
        openssl
      ];
    runScript = pkgs.writeShellScript "qmd-run" ''
      export NPM_CONFIG_PREFIX="$HOME/.cache/qmd-npm"
      export PATH="$HOME/.cache/qmd-npm/bin:$PATH"
      if ! command -v qmd >/dev/null 2>&1; then
        echo "==> installing @tobilu/qmd (first run)" >&2
        npm install -g @tobilu/qmd >&2
      fi
      exec qmd "$@"
    '';
  };
in
{
  home.packages = [ qmdFhs ];
}
