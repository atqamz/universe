{ lib, callPackage }:
lib.genAttrs [
  "codedb"
  "no-mistakes"
  "qmd"
] (name: callPackage (./. + "/${name}") { })
