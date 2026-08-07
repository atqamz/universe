{ inputs, ... }:
let
  mkHost = import ../lib/mkHost.nix { inherit inputs; };

  hostVariants = name: {
    "${name}" = mkHost { hostname = name; };
    "${name}-minimal" = mkHost {
      hostname = name;
      minimal = true;
    };
  };
in
{
  flake.nixosConfigurations = hostVariants "pavg15" // hostVariants "sfx14";
}
