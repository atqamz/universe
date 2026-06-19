{ inputs, ... }:
{
  flake.nixosConfigurations.pavg15 = import ../lib/mkHost.nix { inherit inputs; } {
    hostname = "pavg15";
  };

  flake.nixosConfigurations.pavg15-minimal = import ../lib/mkHost.nix { inherit inputs; } {
    hostname = "pavg15-minimal";
    nixosModule = ../modules/nixos/minimal.nix;
    homeModule = ../modules/home/minimal.nix;
  };
}
