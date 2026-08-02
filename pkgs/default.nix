{ lib, callPackage }:
lib.genAttrs [
  "chrome-devtools-axi"
  "codedb"
  "gh-axi"
  "lavish-axi"
  "no-mistakes"
  "qmd"
  "quota-axi"
  "tasks-axi"
] (name: callPackage (./. + "/${name}") { })
