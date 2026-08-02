{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  nix-update-script,
}:
{
  pname,
  version,
  hash,
  npmDepsHash,
  packageLock,
  description,
}:
buildNpmPackage {
  inherit pname version npmDepsHash;

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = pname;
    tag = "${pname}-v${version}";
    inherit hash;
  };

  postPatch = ''
    cp ${packageLock} package-lock.json
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "${pname}-v(.*)"
      "--override-filename"
      "pkgs/${pname}/default.nix"
    ];
  };

  meta = {
    inherit description;
    homepage = "https://github.com/kunchenguid/${pname}";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
