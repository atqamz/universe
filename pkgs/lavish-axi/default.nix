{ callPackage }:
callPackage ../axi { } {
  pname = "lavish-axi";
  version = "0.1.45";
  hash = "sha256-XJQHsmmSFajQGQopirzOQdR0ztN36ZcC7te2+IjrlFM=";
  npmDepsHash = "sha256-WJXWvcAVvnQbTVz5Kxc79dlVUGTSKQpd+7oxH1brdg0=";
  packageLock = ./package-lock.json;
  description = "Editor for reviewing and annotating rich HTML artifacts produced by AI agents";
}
