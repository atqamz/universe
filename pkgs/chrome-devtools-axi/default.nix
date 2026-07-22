{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  nix-update-script,
}:
buildNpmPackage rec {
  pname = "chrome-devtools-axi";
  version = "0.1.26";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "chrome-devtools-axi";
    tag = "${pname}-v${version}";
    hash = "sha256-csjr1T+a9MPNIw4qxk1TIgFUoGjB8jhrZ+oc6ObcDts=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-yTCuAiZ0+aQJn1w7WCqDqFUWxMV8EE3t9VHWFlmiv50=";

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "${pname}-v(.*)"
    ];
  };

  meta = {
    description = "AXI-compliant chrome-devtools-mcp wrapper with combined operations and TOON output";
    homepage = "https://github.com/kunchenguid/chrome-devtools-axi";
    license = lib.licenses.mit;
    mainProgram = "chrome-devtools-axi";
    platforms = [ "x86_64-linux" ];
  };
}
