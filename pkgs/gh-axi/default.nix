{ callPackage }:
callPackage ../axi { } {
  pname = "gh-axi";
  version = "0.1.29";
  hash = "sha256-xGabDo12fh+YO1ihSo6fyh8bYiELH+iWRDPZ37dMzNI=";
  npmDepsHash = "sha256-09/Ld7zO44aNdQP15xKzThrXA95h0AwSpdT492ejNaM=";
  packageLock = ./package-lock.json;
  description = "AXI-compliant gh CLI wrapper with token-efficient TOON output and contextual suggestions";
}
