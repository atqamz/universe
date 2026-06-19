{ inputs, ... }:
let
  mkHost = import ../lib/mkHost.nix { inherit inputs; };

  # Each host gets a full config and a `-minimal` variant that reuses the same
  # hardware/disko but swaps in the minimal nixos/home modules. The minimal
  # variant is what `disko-install` builds during a reinstall (small enough for
  # the ISO tmpfs); first boot then rebuilds to the full config. Generic so any
  # host (pavg15, sfx14, ...) gets both for free.
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
  flake.nixosConfigurations = hostVariants "pavg15";
}
