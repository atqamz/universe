{ inputs }:
{
  hostname,
  nixosModule ? ../modules/nixos,
  homeModule ? ../modules/home,
}:
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = { inherit inputs hostname; };
  modules = [
    ../hosts/${hostname}
    nixosModule
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    {
      nixpkgs.hostPlatform = "x86_64-linux";
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
