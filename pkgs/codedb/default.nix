{
  stdenv,
  fetchurl,
  lib,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "codedb";
  version = "0.2.5836";

  src = fetchurl {
    url = "https://github.com/justrach/codedb/releases/download/v${finalAttrs.version}/codedb-linux-x86_64";
    hash = "sha256-CvVQoU+tyBCtd3ahYFidO0fcYn/KAyY64c5Hf6juV8s=";
    executable = true;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    install -Dm755 $src $out/bin/codedb
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Code intelligence server for AI agents via MCP";
    homepage = "https://github.com/justrach/codedb";
    license = lib.licenses.bsd3;
    mainProgram = "codedb";
    platforms = [ "x86_64-linux" ];
  };
})
