{ callPackage }:
callPackage ../axi { } {
  pname = "gh-axi";
  version = "0.1.27";
  hash = "sha256-hehWN06+UhCAEACsqn54eNHywlnllY9qHn3c/Fu5Tto=";
  npmDepsHash = "sha256-09/Ld7zO44aNdQP15xKzThrXA95h0AwSpdT492ejNaM=";
  packageLock = ./package-lock.json;
  description = "AXI-compliant gh CLI wrapper with token-efficient TOON output and contextual suggestions";
}
