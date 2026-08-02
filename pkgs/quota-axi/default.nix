{ callPackage }:
callPackage ../axi { } {
  pname = "quota-axi";
  version = "0.1.11";
  hash = "sha256-EBndCJN5Y36RyWHx1vMn0Cad47lEZmWS7SONzigYdA4=";
  npmDepsHash = "sha256-uJJuvzCZ2Gn/Ra7/zyHFLKb0BKD/YEXcACYa8NFCprc=";
  packageLock = ./package-lock.json;
  description = "AXI CLI that reports local agent-provider quota windows without routing or mutation";
}
