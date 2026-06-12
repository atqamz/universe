{ pkgs, ... }:
let
  # qmd self-installs into a machine-local npm prefix on first run. The spike
  # (docs/superpowers/notes/qmd-nixos-spike.md) confirmed node-llama-cpp's
  # prebuilt native addon loads against the nixpkgs node, so no FHS sandbox is
  # needed (and bwrap fails where user namespaces are restricted). We only set
  # LD_LIBRARY_PATH so the prebuilt .node finds libstdc++ at dlopen time.
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
