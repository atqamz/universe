_: {
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs = {
        nixfmt.enable = true;
        shellcheck.enable = true;
        shfmt.enable = true;
      };
      settings.excludes = [
        "configs/dotfiles/**"
        "configs/dotagents/**"
      ];
    };
  };
}
