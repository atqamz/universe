{ config, lib, ... }:
let
  cfg = config.services.userTimers;
in
{
  options.services.userTimers = lib.mkOption {
    default = { };
    description = "Oneshot user services paired with a timer, each wired to notify-failure.";
    type = lib.types.attrsOf (
      lib.types.submodule (submodule: {
        options = {
          description = lib.mkOption {
            type = lib.types.str;
            description = "Service unit description.";
          };

          timerDescription = lib.mkOption {
            type = lib.types.str;
            default = submodule.config.description;
            defaultText = "the service description";
            description = "Timer unit description.";
          };

          command = lib.mkOption {
            type = lib.types.str;
            description = "ExecStart for the oneshot service.";
          };

          timer = lib.mkOption {
            type = lib.types.attrsOf (lib.types.either lib.types.str lib.types.bool);
            description = "Keys for the timer's [Timer] section.";
          };

          wantedBy = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "timers.target" ];
            description = "Targets the timer installs into.";
          };

          unitExtra = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "Extra keys merged into the service's [Unit] section.";
          };

          serviceExtra = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "Extra keys merged into the [Service] section.";
          };

          onActivation = lib.mkOption {
            type = lib.types.enum [
              "never"
              "run"
              "try"
            ];
            default = "never";
            description = "Whether home-manager activation also runs the command, and whether its failure aborts activation.";
          };
        };
      })
    );
  };

  config = {
    systemd.user.services = lib.mapAttrs (_: unit: {
      Unit = {
        Description = unit.description;
        OnFailure = [ "notify-failure@%n.service" ];
      }
      // unit.unitExtra;
      Service = {
        Type = "oneshot";
        ExecStart = unit.command;
      }
      // unit.serviceExtra;
    }) cfg;

    systemd.user.timers = lib.mapAttrs (_: unit: {
      Unit.Description = unit.timerDescription;
      Timer = unit.timer;
      Install.WantedBy = unit.wantedBy;
    }) cfg;

    home.activation = lib.mapAttrs (
      _: unit:
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        "run ${unit.command}" + lib.optionalString (unit.onActivation == "try") " || true"
      )
    ) (lib.filterAttrs (_: unit: unit.onActivation != "never") cfg);
  };
}
