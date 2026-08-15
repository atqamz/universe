{
  inputs,
  self,
  lib,
  ...
}:
{
  perSystem =
    { config, pkgs, ... }:
    let
      sfx14 = self.nixosConfigurations.sfx14;
      gpuService = sfx14.config.systemd.services.gpu-undervolt;
      gpuExec = gpuService.serviceConfig.ExecStart;
      resumeExec = sfx14.config.systemd.services.sleep-actions.serviceConfig.ExecStop;
      gpuUnit =
        pkgs.writeText "sfx14-gpu-undervolt.service"
          sfx14.config.systemd.units."gpu-undervolt.service".text;
      targetModule = "${sfx14.config.hardware.nvidia.package.open}/lib/modules/${sfx14.config.boot.kernelPackages.kernel.modDirVersion}/kernel/drivers/video/nvidia.ko.xz";
      targetSmi = "${sfx14.config.hardware.nvidia.package.bin}/bin/nvidia-smi";
      claude =
        (import inputs.nixpkgs {
          system = pkgs.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        }).claude-code;
    in
    {
      pre-commit.settings.hooks = {
        actionlint.enable = true;
        deadnix.enable = true;
        shellcheck.enable = true;
        statix.enable = true;
        treefmt = {
          enable = true;
          packageOverrides.treefmt = config.treefmt.build.wrapper;
        };
      };

      checks =
        assert lib.elem "gpu-undervolt" sfx14.config.universe.doctor.activeSystemServices;
        lib.mapAttrs' (
          name: host: lib.nameValuePair "toplevel-${name}" host.config.system.build.toplevel
        ) self.nixosConfigurations
        // {
          sfx14-gpu-lifecycle =
            pkgs.runCommand "sfx14-gpu-lifecycle"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  gnugrep
                  systemd
                ];
              }
              ''
                ${pkgs.bash}/bin/bash ${../tests/sfx14-gpu-lifecycle.bash} \
                  ${lib.escapeShellArg gpuExec} \
                  ${lib.escapeShellArg resumeExec} \
                  ${lib.escapeShellArg gpuUnit} \
                  ${lib.escapeShellArg targetModule} \
                  ${lib.escapeShellArg targetSmi} \
                  ${lib.escapeShellArg sfx14.config.hardware.nvidia.package.version}
                touch "$out"
              '';
          no-mistakes-reconcile =
            pkgs.runCommand "no-mistakes-reconcile-test"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  gawk
                  gnugrep
                  gnused
                  jq
                ];
              }
              ''
                bash ${../tests/no-mistakes-reconcile.bash} ${../modules/home/no-mistakes-reconcile.sh}
                touch $out
              '';
          claude-skill-root-contract =
            pkgs.runCommand "claude-skill-root-contract"
              {
                nativeBuildInputs = with pkgs; [
                  claude
                  coreutils
                  gnugrep
                ];
              }
              ''
                help=$(claude plugin init --help)
                grep -Fq 'Scaffold a new plugin at ~/.claude/skills/<name>/' <<<"$help"
                grep -Fq 'auto-loads next session' <<<"$help"
                touch "$out"
              '';
        };
    };
}
