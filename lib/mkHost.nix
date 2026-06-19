{ inputs }:
{
  hostname,
  system ? "x86_64-linux",
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
      nixpkgs.hostPlatform = system;
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
