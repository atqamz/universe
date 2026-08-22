{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  claudeBase = pkgs.claude-code;
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

  claudeOx = pkgs.writeShellApplication {
    name = "claude-ox";
    runtimeInputs = [
      claude
      pkgs.pass
    ];
    text = builtins.readFile ./claude-ox.sh;
  };
in
{
  home = {
    packages = with pkgs; [
      claude
      claudeOx
      codex
      opencode
      inputs.treehouse.packages.${system}.default
      inputs.herdr.packages.${system}.default
      inputs.gw.packages.${system}.default
      inputs.koma.packages.${system}.default
      rtk
      codedb
    ];

    sessionVariables.OPENCODE_DISABLE_AUTOUPDATE = "1";
  };

  universe.doctor = {
    commands = [ "claude-ox" ];
    paths = [ ".password-store/openrouter/api-key.gpg" ];
  };
}
