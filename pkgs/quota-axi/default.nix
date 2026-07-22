{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  nix-update-script,
}:
buildNpmPackage rec {
  pname = "quota-axi";
  version = "0.1.11";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "quota-axi";
    tag = "${pname}-v${version}";
    hash = "sha256-EBndCJN5Y36RyWHx1vMn0Cad47lEZmWS7SONzigYdA4=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-uJJuvzCZ2Gn/Ra7/zyHFLKb0BKD/YEXcACYa8NFCprc=";

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "${pname}-v(.*)"
    ];
  };

  meta = {
    description = "AXI CLI that reports local agent-provider quota windows without routing or mutation";
    homepage = "https://github.com/kunchenguid/quota-axi";
    license = lib.licenses.mit;
    mainProgram = "quota-axi";
    platforms = [ "x86_64-linux" ];
  };
}
