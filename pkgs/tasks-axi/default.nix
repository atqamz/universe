{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
}:
buildNpmPackage rec {
  pname = "tasks-axi";
  version = "0.2.3";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "tasks-axi";
    tag = "${pname}-v${version}";
    hash = "sha256-ziQJdRYtMsJW9xhRtrBiTjDe/5PcECXrBU9Wt9Tn7Vg=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-0mRQQnppQXgF18U+Rau9h8vGqhtRPKGlJ/jQN8/S4sw=";

  meta = {
    description = "AXI-compliant task/backlog CLI with token-efficient TOON output and pluggable backends";
    homepage = "https://github.com/kunchenguid/tasks-axi";
    license = lib.licenses.mit;
    mainProgram = "tasks-axi";
    platforms = [ "x86_64-linux" ];
  };
}
