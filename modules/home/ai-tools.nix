{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  claudeBase = inputs.claude-code.packages.${system}.default;
  nodeShim = pkgs.writeShellScriptBin "node" ''exec ${pkgs.bun}/bin/bun "$@"'';
  npxShim = pkgs.writeShellScriptBin "npx" ''exec ${pkgs.bun}/bin/bunx "$@"'';
  claude = pkgs.symlinkJoin {
    name = "claude-code";
    paths = [ claudeBase ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/claude
      makeWrapper ${claudeBase}/bin/claude $out/bin/claude \
        --prefix PATH : ${
          lib.makeBinPath [
            nodeShim
            npxShim
            pkgs.bun
          ]
        }
    '';
  };
in
{
  home = {
    packages = with pkgs; [
      claude
      codex
      opencode
      inputs.treehouse.packages.${system}.default
      inputs.herdr.packages.${system}.default
      inputs.gw.packages.${system}.default
      inputs.koma.packages.${system}.default
      rtk
      codedb
      no-mistakes
    ];

    sessionVariables.OPENCODE_DISABLE_AUTOUPDATE = "1";
  };
}
