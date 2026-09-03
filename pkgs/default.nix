{ lib, callPackage }:
lib.genAttrs [
  "codedb"
  "fastpotify"
  "hyprwhspr"
  "no-mistakes"
  "unity-cli"
] (name: callPackage (./. + "/${name}") { })
