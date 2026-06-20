{ pkgs, ... }:
let
  qmd = pkgs.writeShellApplication {
    name = "qmd";
    runtimeInputs = [ pkgs.nodejs_22 ];
    text = ''
      export NPM_CONFIG_PREFIX="$HOME/.cache/qmd-npm"
      export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      qmd_bin="$HOME/.cache/qmd-npm/bin/qmd"
      if [ ! -x "$qmd_bin" ]; then
        echo "==> installing @tobilu/qmd (first run)" >&2
        npm install -g @tobilu/qmd >&2
      fi
      exec "$qmd_bin" "$@"
    '';
  };
in
{
  home.packages = [ qmd ];
}
