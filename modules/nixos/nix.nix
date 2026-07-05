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
    fallback = true;
    connect-timeout = 5;
    stalled-download-timeout = 20;
    download-attempts = 2;
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nixpkgs.config.allowUnfree = true;
}
