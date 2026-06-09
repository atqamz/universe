{ inputs, ... }:
{
  flake.nixosConfigurations.pavg15 = import ../lib/mkHost.nix { inherit inputs; } {
    hostname = "pavg15";
  };
}
