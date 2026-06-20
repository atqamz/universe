{ inputs, ... }:
let
  mkHost = import ../lib/mkHost.nix { inherit inputs; };

  hostVariants = name: {
    "${name}" = mkHost { hostname = name; };
    "${name}-minimal" = mkHost {
      hostname = name;
      nixosModule = ../modules/nixos/minimal.nix;
      homeModule = ../modules/home/minimal.nix;
    };
  };
in
{
  flake.nixosConfigurations = hostVariants "pavg15" // hostVariants "sfx14";
}
