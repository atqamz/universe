{ lib, callPackage }:
lib.genAttrs [
  "codedb"
  "no-mistakes"
  "unity-cli"
] (name: callPackage (./. + "/${name}") { })
