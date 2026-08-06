{
  stdenv,
  lib,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  cacert,
  curl,
  gnupg,
  jq,
  nix-update,
  unzip,
  writeShellApplication,
}:
let
  platform =
    {
      x86_64-linux = {
        arch = "x64";
        hash = "sha256-m4mqpaZ26OW9ajhEqTmN77ljvTSVGGRFpGSkcFflTqM=";
      };
      aarch64-linux = {
        arch = "arm64";
        hash = "sha256-Idor+Y0W261V3Tuxh6AQCKz+CDlgdeSRiA2X2Bip7xE=";
      };
    }
    .${stdenv.hostPlatform.system};

  updateScript = writeShellApplication {
    name = "update-unity-cli";
    runtimeInputs = [
      curl
      jq
      nix-update
    ];
    text = ''
      version=$(curl -fsSL https://public-cdn.cloud.unity3d.com/hub/prod/cli/latest-beta.json | jq -er '.version | select(type == "string" and length > 0)')
      exec nix-update --flake \
        --override-filename pkgs/unity-cli/default.nix \
        --version "$version" \
        unity-cli
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "unity-cli";
  version = "1.0.0-beta.3";

  src = fetchurl {
    url = "https://public-cdn.cloud.unity3d.com/hub/prod/cli/${finalAttrs.version}/unity-linux-${platform.arch}";
    inherit (platform) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    install -Dm755 $src $out/bin/.unity-unwrapped
    makeWrapper $out/bin/.unity-unwrapped $out/bin/unity \
      --prefix PATH : ${
        lib.makeBinPath [
          gnupg
          unzip
        ]
      } \
      --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
  '';

  passthru.updateScript = [ (lib.getExe updateScript) ];

  meta = {
    description = "Command-line interface for Unity Editors, projects, and Unity Cloud";
    homepage = "https://docs.unity.com/en-us/unity-cli/use-unity-cli";
    license = lib.licenses.unfree;
    mainProgram = "unity";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
