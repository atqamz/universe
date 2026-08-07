{ inputs }:
{
  hostname,
  minimal ? false,
  hostModule ? ../hosts/${hostname},
  fullHostModule ? ../hosts/${hostname}/full.nix,
  nixosModule ? if minimal then ../modules/nixos/minimal.nix else ../modules/nixos,
  homeModule ? ../modules/home,
}:
let
  lib = inputs.nixpkgs.lib;
in
lib.nixosSystem {
  specialArgs = { inherit inputs hostname minimal; };
  modules = [
    hostModule
  ]
  ++ lib.optional (!minimal) fullHostModule
  ++ [
    nixosModule
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    {
      nixpkgs.hostPlatform = "x86_64-linux";
    }
  ]
  ++ lib.optionals (!minimal) [
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        extraSpecialArgs = { inherit inputs hostname; };
        users.atqa = homeModule;
      };
    }
  ];
}
