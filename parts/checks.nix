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
      opencodeProviderContract = import ../lib/opencode-provider-contract.nix;
      opencodeProviderHealthy = pkgs.writeText "opencode-provider-healthy.json" (
        builtins.toJSON {
          provider.mocin = {
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "https://beta.masven.dev/v1";
            models.A = { };
          };
        }
      );
      opencodeProviderMissing = pkgs.writeText "opencode-provider-missing.json" (
        builtins.toJSON { provider = { }; }
      );
      opencodeProviderWrongNpm = pkgs.writeText "opencode-provider-wrong-npm.json" (
        builtins.toJSON {
          provider.mocin = {
            npm = "other-sdk";
            options.baseURL = "https://beta.masven.dev/v1";
            models.A = { };
          };
        }
      );
      opencodeProviderWrongUrl = pkgs.writeText "opencode-provider-wrong-url.json" (
        builtins.toJSON {
          provider.mocin = {
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "https://other.example/v1";
            models.A = { };
          };
        }
      );
      opencodeProviderEmptyModels = pkgs.writeText "opencode-provider-empty-models.json" (
        builtins.toJSON {
          provider.mocin = {
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "https://beta.masven.dev/v1";
            models = { };
          };
        }
      );
      opencodeProviderNonObjectModels = pkgs.writeText "opencode-provider-nonobject-models.json" (
        builtins.toJSON {
          provider.mocin = {
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "https://beta.masven.dev/v1";
            models = [ "A" ];
          };
        }
      );
      opencodeProviderMalformed = pkgs.writeText "opencode-provider-malformed.json" "{";
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
          opencode-provider-contract =
            pkgs.runCommand "opencode-provider-contract"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  jq
                ];
              }
              ''
                expect_success() {
                  if ! "$@" >/dev/null; then
                    echo "expected command to succeed: $*" >&2
                    exit 1
                  fi
                }

                expect_failure() {
                  if "$@" >/dev/null 2>&1; then
                    echo "expected command to fail: $*" >&2
                    exit 1
                  fi
                }

                provider_args=(--arg p mocin --arg n '@ai-sdk/openai-compatible' --arg u 'https://beta.masven.dev/v1')
                expect_success jq -e "''${provider_args[@]}" '${opencodeProviderContract.provider}' ${opencodeProviderHealthy}
                expect_success jq -e --arg p mocin '${opencodeProviderContract.models}' ${opencodeProviderHealthy}
                expect_failure jq -e "''${provider_args[@]}" '${opencodeProviderContract.provider}' ${opencodeProviderMissing}
                expect_failure jq -e "''${provider_args[@]}" '${opencodeProviderContract.provider}' ${opencodeProviderWrongNpm}
                expect_failure jq -e "''${provider_args[@]}" '${opencodeProviderContract.provider}' ${opencodeProviderWrongUrl}
                expect_failure jq -e --arg p mocin '${opencodeProviderContract.models}' ${opencodeProviderEmptyModels}
                expect_failure jq -e --arg p mocin '${opencodeProviderContract.models}' ${opencodeProviderNonObjectModels}
                expect_failure jq -e . ${opencodeProviderMalformed}
                touch "$out"
              '';
        };
    };
}
