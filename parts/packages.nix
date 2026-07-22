_: {
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        codedb = pkgs.callPackage ../pkgs/codedb { };
        no-mistakes = pkgs.callPackage ../pkgs/no-mistakes { };
        chrome-devtools-axi = pkgs.callPackage ../pkgs/chrome-devtools-axi { };
        gh-axi = pkgs.callPackage ../pkgs/gh-axi { };
        lavish-axi = pkgs.callPackage ../pkgs/lavish-axi { };
        quota-axi = pkgs.callPackage ../pkgs/quota-axi { };
        tasks-axi = pkgs.callPackage ../pkgs/tasks-axi { };
      };
    };
}
