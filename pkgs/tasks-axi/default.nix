{ callPackage }:
callPackage ../axi { } {
  pname = "tasks-axi";
  version = "0.2.4";
  hash = "sha256-GuD6gjE09IObnZr6kKWvbx56WOBRvbtuXOXRrKb2BUo=";
  npmDepsHash = "sha256-0mRQQnppQXgF18U+Rau9h8vGqhtRPKGlJ/jQN8/S4sw=";
  packageLock = ./package-lock.json;
  description = "AXI-compliant task/backlog CLI with token-efficient TOON output and pluggable backends";
}
