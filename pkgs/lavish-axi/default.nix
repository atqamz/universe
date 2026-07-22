{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  nix-update-script,
}:
buildNpmPackage rec {
  pname = "lavish-axi";
  version = "0.1.42";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "lavish-axi";
    tag = "${pname}-v${version}";
    hash = "sha256-IcApX4Qpx7oy5x5uaeOlIFC/6pr/kjjcjjPjmCXk2DI=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-WJXWvcAVvnQbTVz5Kxc79dlVUGTSKQpd+7oxH1brdg0=";

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "${pname}-v(.*)"
    ];
  };

  meta = {
    description = "Editor for reviewing and annotating rich HTML artifacts produced by AI agents";
    homepage = "https://github.com/kunchenguid/lavish-axi";
    license = lib.licenses.mit;
    mainProgram = "lavish-axi";
    platforms = [ "x86_64-linux" ];
  };
}
