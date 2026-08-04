{ callPackage }:
callPackage ../axi { } {
  pname = "chrome-devtools-axi";
  version = "0.1.28";
  hash = "sha256-ST2x1+KQM4X/3KtbHUr+O5o6m8CLB50SzDVzMLbspno=";
  npmDepsHash = "sha256-2tpxuL1yNPIqm34Xbo5wVC10SjdOA7X9f0sHt7BkwKM=";
  packageLock = ./package-lock.json;
  description = "AXI-compliant chrome-devtools-mcp wrapper with combined operations and TOON output";
}
