{
  description = "universe - personal infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      sops-nix,
      disko,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      nixosConfigurations.pavg15 = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/pavg15
          ./modules/nixos/server.nix
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          { nixpkgs.hostPlatform = system; }
        ];
      };

      checks.${system}.pavg15 = self.nixosConfigurations.pavg15.config.system.build.toplevel;

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          deadnix
          nixfmt-rfc-style
          statix
        ];
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
