{ lib, callPackage }:
lib.genAttrs [
  "codedb"
  "no-mistakes"
  "qmd"
  "unity-cli"
] (name: callPackage (./. + "/${name}") { })
