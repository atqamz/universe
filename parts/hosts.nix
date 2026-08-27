{ inputs, ... }:
let
  mkHost = import ../lib/mkHost.nix { inherit inputs; };

  hostVariants = name: args: {
    "${name}" = mkHost ({ hostname = name; } // args);
    "${name}-minimal" = mkHost {
      hostname = name;
      minimal = true;
    };
  };
in
{
  flake.nixosConfigurations = hostVariants "pavg15" { server = true; } // hostVariants "sfx14" { };
}
