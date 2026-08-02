{ callPackage }:
callPackage ../axi { } {
  pname = "chrome-devtools-axi";
  version = "0.1.26";
  hash = "sha256-csjr1T+a9MPNIw4qxk1TIgFUoGjB8jhrZ+oc6ObcDts=";
  npmDepsHash = "sha256-yTCuAiZ0+aQJn1w7WCqDqFUWxMV8EE3t9VHWFlmiv50=";
  packageLock = ./package-lock.json;
  description = "AXI-compliant chrome-devtools-mcp wrapper with combined operations and TOON output";
}
