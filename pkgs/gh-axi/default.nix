{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
}:
buildNpmPackage rec {
  pname = "gh-axi";
  version = "0.1.27";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "gh-axi";
    tag = "${pname}-v${version}";
    hash = "sha256-hehWN06+UhCAEACsqn54eNHywlnllY9qHn3c/Fu5Tto=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-09/Ld7zO44aNdQP15xKzThrXA95h0AwSpdT492ejNaM=";

  meta = {
    description = "AXI-compliant gh CLI wrapper with token-efficient TOON output and contextual suggestions";
    homepage = "https://github.com/kunchenguid/gh-axi";
    license = lib.licenses.mit;
    mainProgram = "gh-axi";
    platforms = [ "x86_64-linux" ];
  };
}
