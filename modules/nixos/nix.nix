_: {
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    extra-substituters = [ "https://atqamz-universe.cachix.org" ];
    extra-trusted-public-keys = [
      "atqamz-universe.cachix.org-1:XTxFJDQxSXjQ+mu7oHYN8udmwDkCccjIbihvb8ZNJKU="
    ];
  };
  nixpkgs.config.allowUnfree = true;
}
