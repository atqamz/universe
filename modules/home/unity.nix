{
  pkgs,
  lib,
  config,
  ...
}:
let
  prime = import ../../lib/prime.nix { inherit lib; };

  unityhubBase = pkgs.unityhub.override {
    extraPkgs =
      p: with p; [
        python3
        shared-mime-info
      ];
  };

  unityhub = pkgs.symlinkJoin {
    name = "unityhub-offload";
    paths = [ unityhubBase ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/unityhub
      makeWrapper ${unityhubBase}/bin/unityhub $out/bin/unityhub \
        ${prime.wrapperArgs} \
        --prefix PATH : ${lib.makeBinPath [ pkgs.ffmpeg ]}

      desktop=$out/share/applications/unityhub.desktop
      if [ -e "$desktop" ]; then
        src=$(readlink -f "$desktop")
        rm -f "$desktop"
        substitute "$src" "$desktop" \
          --replace-fail "${unityhubBase}/opt/unityhub/unityhub" "$out/bin/unityhub"
      fi
    '';
  };

  unity-editor = pkgs.writeShellScriptBin "unity-editor" ''
    ${prime.exports}
    editor="''${FM_UNITY_EDITOR:-}"
    if [ -z "$editor" ]; then
      editor=$(ls -d "$HOME"/Unity/Hub/Editor/*/Editor/Unity 2>/dev/null | sort -V | tail -1)
    fi
    if [ -z "$editor" ] || [ ! -x "$editor" ]; then
      echo "unity-editor: no editor under ~/Unity/Hub/Editor/*/Editor/Unity (set FM_UNITY_EDITOR)" >&2
      exit 1
    fi
    exec ${unityhubBase.fhsEnv}/bin/unityhub-fhs-env "$editor" "$@"
  '';
in
{
  home = {
    sessionPath = [ "${config.home.homeDirectory}/.unity/bin" ];
    packages = [
      unityhub
      unity-editor
    ];
  };
}
