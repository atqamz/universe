{ callPackage }:
callPackage ../axi { } {
  pname = "quota-axi";
  version = "0.1.17";
  hash = "sha256-uZX6l+90UehBHmp/p22DkNvgIc2nx9HnKeP8sK7e0jM=";
  npmDepsHash = "sha256-G2Lca/x5rf28hK+J2r/YzDeIhsIxqMTl/vh8Z1k7Blc=";
  packageLock = ./package-lock.json;
  description = "AXI CLI that reports local agent-provider quota windows without routing or mutation";
}
