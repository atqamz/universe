{ inputs }:
{
  hostname,
  minimal ? false,
  server ? false,
  hostModule ? ../hosts/${hostname},
  fullHostModule ? ../hosts/${hostname}/full.nix,
  nixosModule ?
    if minimal then
      ../modules/nixos/minimal.nix
    else if server then
      ../modules/nixos/server.nix
    else
      ../modules/nixos,
  homeModule ? ../modules/home,
}:
let
  lib = inputs.nixpkgs.lib;
  headless = minimal || server;
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
  ++ lib.optionals (!headless) [
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
