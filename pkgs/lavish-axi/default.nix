{ callPackage }:
callPackage ../axi { } {
  pname = "lavish-axi";
  version = "0.1.42";
  hash = "sha256-IcApX4Qpx7oy5x5uaeOlIFC/6pr/kjjcjjPjmCXk2DI=";
  npmDepsHash = "sha256-WJXWvcAVvnQbTVz5Kxc79dlVUGTSKQpd+7oxH1brdg0=";
  packageLock = ./package-lock.json;
  description = "Editor for reviewing and annotating rich HTML artifacts produced by AI agents";
}
