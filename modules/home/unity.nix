{
  pkgs,
  lib,
  ...
}:
let
  prime = import ../../lib/prime.nix { inherit lib; };

  unityBase = pkgs.unityhub.override {
    extraPkgs =
      p: with p; [
        ffmpeg
        python3
        shared-mime-info
        sqlite
      ];
  };

  unityhub = pkgs.symlinkJoin {
    name = "unityhub-offload";
    paths = [ unityBase ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/unityhub
      makeWrapper ${unityBase}/bin/unityhub $out/bin/unityhub \
        ${prime.wrapperArgs}

      desktop=$out/share/applications/unityhub.desktop
      if [ -e "$desktop" ]; then
        src=$(readlink -f "$desktop")
        rm -f "$desktop"
        substitute "$src" "$desktop" \
          --replace-fail "${unityBase}/opt/unityhub/unityhub" "$out/bin/unityhub"
      fi
    '';
  };

  unity = pkgs.writeShellScriptBin "unity" ''
    ${prime.exports}
    exec ${unityBase.fhsEnv}/bin/unityhub-fhs-env ${lib.getExe pkgs.unity-cli} "$@"
  '';

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
    exec ${unityBase.fhsEnv}/bin/unityhub-fhs-env "$editor" "$@"
  '';
in
{
  home.packages = [
    unity
    unityhub
    unity-editor
  ];
}
