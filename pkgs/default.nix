{ lib, callPackage }:
lib.genAttrs [
  "codedb"
  "hyprwhspr"
  "no-mistakes"
  "unity-cli"
] (name: callPackage (./. + "/${name}") { })
