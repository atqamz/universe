{ inputs }:
{ hostname, system ? "x86_64-linux" }:
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = { inherit inputs hostname; };
  modules = [
    ../hosts/${hostname}
    inputs.home-manager.nixosModules.home-manager
    {
      nixpkgs.hostPlatform = system;
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        extraSpecialArgs = { inherit inputs; };
        users.atqa = ../modules/home;
      };
    }
  ];
}
